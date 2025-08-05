#Requires -Version 5.1

# Set strict error handling
$ErrorActionPreference = "Stop"

# Module-level variables
$script:ModuleRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:LogPath = $null
$script:BackupDirectory = $null

#region Logging Functions
function Write-Log {
    <#
    .SYNOPSIS
        Write message to log file and console
    .DESCRIPTION
        Writes a timestamped message to both the log file and console with appropriate color coding
    .PARAMETER Message
        The message to log
    .PARAMETER Level
        The log level (INFO, WARN, ERROR, SUCCESS)
    .EXAMPLE
        Write-Log "Starting operation" -Level "INFO"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("INFO", "WARN", "ERROR", "SUCCESS")]
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    try {
        if ($script:LogPath) {
            Add-Content -Path $script:LogPath -Value $logEntry -Encoding UTF8 -ErrorAction SilentlyContinue
        }
    }
    catch {
        Write-Warning "Failed to write to log file: $_"
    }
    
    switch ($Level) {
        "INFO" { Write-Host $Message -ForegroundColor White }
        "SUCCESS" { Write-Host $Message -ForegroundColor Green }
        "WARN" { Write-Warning $Message }
        "ERROR" { Write-Error $Message }
    }
}

function Initialize-Logging {
    <#
    .SYNOPSIS
        Initialize logging system
    .DESCRIPTION
        Sets up the logging system with the specified log path
    .PARAMETER LogPath
        Path to the log file
    .EXAMPLE
        Initialize-Logging -LogPath "C:\Logs\configure-wsl.log"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$LogPath = "$env:TEMP\configure-wsl.log"
    )
    
    $script:LogPath = $LogPath
    $script:BackupDirectory = "$env:TEMP\wsl-config-backups-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    
    try {
        $logDir = Split-Path $script:LogPath -Parent
        if (-not (Test-Path $logDir)) {
            New-Item -Path $logDir -ItemType Directory -Force | Out-Null
        }
        
        $startMessage = "=== WSL Configuration Module Started ==="
        Add-Content -Path $script:LogPath -Value $startMessage -Encoding UTF8
        Write-Log "Log file initialized at: $script:LogPath" -Level "INFO"
    }
    catch {
        Write-Warning "Failed to initialize logging: $_"
        $script:LogPath = $null
    }
}
#endregion

#region Validation Functions
function Test-IsAdministrator {
    <#
    .SYNOPSIS
        Check if running as Administrator
    .DESCRIPTION
        Tests whether the current PowerShell session is running with Administrator privileges
    .OUTPUTS
        System.Boolean - True if running as Administrator, False otherwise
    .EXAMPLE
        if (Test-IsAdministrator) { Write-Host "Running as Admin" }
    #>
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param()
    
    try {
        $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch {
        Write-Log "Error checking administrator status: $_" -Level "ERROR"
        return $false
    }
}

function Test-WSLInstallation {
    <#
    .SYNOPSIS
        Test if WSL is installed and properly configured
    .DESCRIPTION
        Checks the WSL installation status and returns detailed information
    .OUTPUTS
        PSCustomObject with IsInstalled, IsEnabled, and Version properties
    .EXAMPLE
        $wslStatus = Test-WSLInstallation
        if ($wslStatus.IsInstalled) { Write-Host "WSL is installed" }
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()
    
    $result = [PSCustomObject]@{
        IsInstalled = $false
        IsEnabled = $false
        Version = $null
    }
    
    try {
        # Method 1: Try to execute wsl.exe
        $wslCommand = Get-Command "wsl.exe" -ErrorAction SilentlyContinue
        if ($wslCommand) {
            # WSL executable exists, test if it works
            $wslOutput = & wsl.exe --status 2>$null
            if ($LASTEXITCODE -eq 0) {
                $result.IsInstalled = $true
                $result.IsEnabled = $true
                
                # Try to get version information
                try {
                    $versionOutput = & wsl.exe --version 2>$null
                    if ($LASTEXITCODE -eq 0 -and $versionOutput) {
                        $result.Version = ($versionOutput | Select-Object -First 1).Trim()
                    }
                    else {
                        $result.Version = "WSL1 or Unknown"
                    }
                }
                catch {
                    $result.Version = "Unknown"
                }
            }
            else {
                # WSL exists but might not be enabled
                $result.IsInstalled = $true
                $result.IsEnabled = $false
            }
        }
        else {
            # Method 2: Check Windows Features if wsl.exe doesn't exist
            $wslFeature = Get-WindowsOptionalFeature -Online -FeatureName "Microsoft-Windows-Subsystem-Linux" -ErrorAction SilentlyContinue
            if ($wslFeature) {
                $result.IsInstalled = $true
                $result.IsEnabled = ($wslFeature.State -eq "Enabled")
                $result.Version = "WSL Feature Available"
            }
        }
    }
    catch {
        Write-Log "Error checking WSL installation status: $_" -Level "WARN"
    }
    
    return $result
}

function Test-Prerequisites {
    <#
    .SYNOPSIS
        Validate system prerequisites
    .DESCRIPTION
        Checks Windows version, WSL availability, and internet connectivity
    .OUTPUTS
        System.Boolean - True if prerequisites are met
    .EXAMPLE
        if (Test-Prerequisites) { Write-Host "System ready" }
    #>
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param()
    
    Write-Log "Checking system prerequisites..." -Level "INFO"
    
    try {
        # Check Windows version
        $windowsVersion = [System.Environment]::OSVersion.Version
        if ($windowsVersion.Major -lt 10) {
            throw "Windows 10 or later is required for WSL"
        }
        
        # Enhanced Windows version check for WSL2
        $buildNumber = [System.Environment]::OSVersion.Version.Build
        if ($windowsVersion.Major -eq 10 -and $buildNumber -lt 19041) {
            Write-Log "Warning: WSL2 requires Windows 10 version 2004 (build 19041) or later. Current build: $buildNumber" -Level "WARN"
            Write-Log "WSL1 may still work, but WSL2 is recommended for better performance" -Level "WARN"
        }
        
        # Check WSL installation status
        $wslStatus = Test-WSLInstallation
        if ($wslStatus.IsInstalled -eq $false) {
            Write-Log "WSL is not installed. Manual installation required." -Level "WARN"
            return $false
        }
        elseif ($wslStatus.IsEnabled -eq $false) {
            Write-Log "WSL feature is installed but not enabled. Manual enablement required." -Level "WARN"
            return $false
        }
        else {
            Write-Log "WSL is properly installed and available (Version: $($wslStatus.Version))" -Level "SUCCESS"
        }
        
        # Check internet connectivity
        try {
            $testConnection = Test-NetConnection -ComputerName "github.com" -Port 443 -InformationLevel Quiet -WarningAction SilentlyContinue
            if (-not $testConnection) {
                Write-Log "Warning: Internet connectivity test failed" -Level "WARN"
            }
        }
        catch {
            Write-Log "Warning: Could not verify internet connectivity" -Level "WARN"
        }
        
        Write-Log "Prerequisites check completed successfully" -Level "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Prerequisites check failed: $_" -Level "ERROR"
        return $false
    }
}
#endregion

#region Backup Functions
function New-ConfigurationBackup {
    <#
    .SYNOPSIS
        Create backup of configuration files before modification
    .DESCRIPTION
        Creates a backup copy of the specified file in the backup directory
    .PARAMETER FilePath
        Path to the file to backup
    .PARAMETER BackupName
        Optional custom name for the backup file
    .OUTPUTS
        System.String - Path to the backup file, or $null if backup failed
    .EXAMPLE
        $backup = New-ConfigurationBackup -FilePath "C:\config.json"
    #>
    [CmdletBinding()]
    [OutputType([System.String])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        
        [Parameter(Mandatory = $false)]
        [string]$BackupName
    )
    
    if (-not (Test-Path $FilePath)) {
        return $null
    }
    
    try {
        if (-not (Test-Path $script:BackupDirectory)) {
            New-Item -Path $script:BackupDirectory -ItemType Directory -Force | Out-Null
        }
        
        if (-not $BackupName) {
            $BackupName = Split-Path $FilePath -Leaf
        }
        
        $backupPath = Join-Path $script:BackupDirectory "$BackupName.backup"
        Copy-Item -Path $FilePath -Destination $backupPath -Force
        
        Write-Log "Created backup: $backupPath" -Level "INFO"
        return $backupPath
    }
    catch {
        Write-Log "Failed to create backup for $FilePath : $_" -Level "WARN"
        return $null
    }
}
#endregion

#region WSL Functions
function Install-WSLDistribution {
    <#
    .SYNOPSIS
        Install WSL distribution if not present
    .DESCRIPTION
        Installs the specified WSL distribution using modern WSL commands
    .PARAMETER DistroName
        Name of the WSL distribution to install
    .OUTPUTS
        System.Boolean - True if installation succeeded
    .EXAMPLE
        Install-WSLDistribution -DistroName "Ubuntu"
    #>
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DistroName
    )
    
    Write-Log "Checking for WSL distribution: $DistroName" -Level "INFO"
    
    try {
        # First, verify WSL is working
        $wslTest = & wsl.exe --status 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Log "WSL is not ready. Testing basic functionality..." -Level "WARN"
            
            # Try a simple command to verify WSL works
            $wslVersion = & wsl.exe --version 2>$null
            if ($LASTEXITCODE -ne 0) {
                throw "WSL is installed but not functioning properly. You may need to restart your computer."
            }
        }
        
        # Check existing distributions
        $existingDistros = @()
        try {
            $distroList = & wsl.exe --list --quiet 2>$null
            if ($LASTEXITCODE -eq 0 -and $distroList) {
                $existingDistros = $distroList | Where-Object { $_ -ne "" -and $_.Trim() -ne "" } | ForEach-Object { $_.Trim() }
            }
        }
        catch {
            Write-Log "Could not list existing distributions, proceeding with installation" -Level "WARN"
        }
        
        # Check if distribution already exists
        $distroExists = $false
        foreach ($distro in $existingDistros) {
            if ($distro -eq $DistroName -or $distro -like "*$DistroName*") {
                $distroExists = $true
                break
            }
        }
        
        if ($distroExists) {
            Write-Log "Distribution '$DistroName' is already installed" -Level "SUCCESS"
            return $true
        }
        
        Write-Log "Installing WSL distribution: $DistroName" -Level "INFO"
        Write-Log "This may take several minutes..." -Level "INFO"
        
        # Use wsl --install with --no-launch for automation
        $installArgs = @("--install", "-d", $DistroName, "--no-launch")
        Write-Log "Executing: wsl.exe $($installArgs -join ' ')" -Level "INFO"
        
        $installProcess = Start-Process -FilePath "wsl.exe" -ArgumentList $installArgs -Wait -PassThru -NoNewWindow
        
        if ($installProcess.ExitCode -eq 0) {
            Write-Log "WSL distribution '$DistroName' installation completed successfully" -Level "SUCCESS"
            return $true
        }
        else {
            Write-Log "WSL distribution installation failed with exit code: $($installProcess.ExitCode)" -Level "ERROR"
            return $false
        }
    }
    catch {
        Write-Log "Error during WSL distribution installation: $_" -Level "ERROR"
        return $false
    }
}

function Install-StarshipInWSL {
    <#
    .SYNOPSIS
        Install Starship prompt in WSL
    .DESCRIPTION
        Installs and configures Starship prompt in the specified WSL distribution
    .PARAMETER DistroName
        Name of the WSL distribution to configure
    .OUTPUTS
        System.Boolean - True if installation succeeded
    .EXAMPLE
        Install-StarshipInWSL -DistroName "Ubuntu"
    #>
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DistroName
    )
    
    Write-Log "Installing Starship and dependencies in WSL: $DistroName" -Level "INFO"
    
    $wslScript = @'
#!/bin/bash
set -e

# Suppress interactive prompts
export DEBIAN_FRONTEND=noninteractive

echo "Updating package lists..."
sudo apt-get update -qq

echo "Installing dependencies..."
sudo apt-get install -y curl unzip fonts-firacode

echo "Installing Starship prompt..."
curl -sS https://starship.rs/install.sh | sh -s -- -y

echo "Configuring shell integration..."
# Configure bash
BASHRC="$HOME/.bashrc"
if ! grep -q "starship init" "$BASHRC" 2>/dev/null; then
    echo 'eval "$(starship init bash)"' >> "$BASHRC"
    echo "Added Starship to .bashrc"
fi

# Configure zsh if present
if [ -f "$HOME/.zshrc" ]; then
    if ! grep -q "starship init" "$HOME/.zshrc" 2>/dev/null; then
        echo 'eval "$(starship init zsh)"' >> "$HOME/.zshrc"
        echo "Added Starship to .zshrc"
    fi
fi

echo "Starship installation completed successfully"
'@
    
    try {
        # Create script in WSL-accessible location using base64 encoding
        $wslTempPath = "/tmp/starship-install-$(Get-Date -Format 'yyyyMMdd-HHmmss').sh"
        
        # Encode script content to base64 to safely transfer to WSL
        Write-Log "Creating installation script in WSL..." -Level "INFO"
        $scriptBytes = [System.Text.Encoding]::UTF8.GetBytes($wslScript)
        $base64Script = [System.Convert]::ToBase64String($scriptBytes)
        
        # Create and decode script in WSL
        $createScriptCmd = "echo '$base64Script' | base64 -d > $wslTempPath && chmod +x $wslTempPath"
        $createResult = & wsl.exe -d $DistroName bash -c $createScriptCmd
        
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to create installation script in WSL"
        }
        
        # Execute the script within WSL
        Write-Log "Executing Starship installation script..." -Level "INFO"
        $wslProcess = Start-Process -FilePath "wsl.exe" -ArgumentList "-d", $DistroName, "bash", $wslTempPath -Wait -PassThru -NoNewWindow
        
        # Clean up the script file in WSL
        & wsl.exe -d $DistroName rm -f $wslTempPath 2>$null
        
        if ($wslProcess.ExitCode -eq 0) {
            Write-Log "Starship installation completed successfully" -Level "SUCCESS"
            return $true
        }
        else {
            Write-Log "Starship installation failed with exit code: $($wslProcess.ExitCode)" -Level "ERROR"
            return $false
        }
    }
    catch {
        Write-Log "Error during Starship installation: $_" -Level "ERROR"
        return $false
    }
}
#endregion

#region Font Functions
function Install-FiraCodeFont {
    <#
    .SYNOPSIS
        Install FiraCode Nerd Font
    .DESCRIPTION
        Downloads and installs FiraCode Nerd Font for use in terminals and editors
    .OUTPUTS
        System.Boolean - True if installation succeeded
    .EXAMPLE
        Install-FiraCodeFont
    #>
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param()
    
    Write-Log "Installing FiraCode Nerd Font" -Level "INFO"
    
    # Load required assemblies for font operations
    try {
        Add-Type -AssemblyName System.Drawing
        Write-Log "System.Drawing assembly loaded successfully" -Level "INFO"
    }
    catch {
        Write-Log "Warning: Could not load System.Drawing assembly: $_" -Level "WARN"
        Write-Log "Proceeding with basic font installation method" -Level "INFO"
    }
    
    $fontUrl = "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip"
    $zipPath = "$env:TEMP\FiraCode-$(Get-Date -Format 'yyyyMMdd-HHmmss').zip"
    $extractPath = "$env:TEMP\FiraCodeFont-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    
    try {
        # Download with secure settings
        Write-Log "Downloading FiraCode Nerd Font..." -Level "INFO"
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        
        $webClient = New-Object System.Net.WebClient
        $webClient.Headers.Add("User-Agent", "PowerShell WSL Configuration Script")
        $webClient.DownloadFile($fontUrl, $zipPath)
        $webClient.Dispose()
        
        # Extract fonts
        Write-Log "Extracting font files..." -Level "INFO"
        Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
        
        # Install fonts using modern approach
        $fontFiles = Get-ChildItem -Path $extractPath -Filter "*.ttf" -Recurse
        $installedCount = 0
        
        foreach ($fontFile in $fontFiles) {
            try {
                # Get the system Fonts directory
                $fontsDirectory = [Environment]::GetFolderPath("Fonts")
                $destinationPath = Join-Path $fontsDirectory $fontFile.Name
                
                if (-not (Test-Path $destinationPath)) {
                    # Copy font to system fonts directory
                    Copy-Item -Path $fontFile.FullName -Destination $destinationPath -Force
                    
                    # Register font with Windows (for better compatibility)
                    try {
                        $shell = New-Object -ComObject Shell.Application
                        $fontsFolder = $shell.Namespace(0x14)  # Fonts folder
                        $fontsFolder.CopyHere($fontFile.FullName, 0x10)  # Don't show progress
                    }
                    catch {
                        # Fallback: Just copy the file (already done above)
                        Write-Log "Used fallback font installation for $($fontFile.Name)" -Level "INFO"
                    }
                    
                    Write-Log "Installed font: $($fontFile.Name)" -Level "SUCCESS"
                    $installedCount++
                }
                else {
                    Write-Log "Font already exists: $($fontFile.Name)" -Level "INFO"
                }
            }
            catch {
                Write-Log "Failed to install font $($fontFile.Name): $_" -Level "WARN"
            }
        }
        
        Write-Log "Font installation completed. Installed $installedCount new fonts." -Level "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Error during font installation: $_" -Level "ERROR"
        return $false
    }
    finally {
        # Cleanup temporary files
        try {
            if (Test-Path $zipPath) {
                Remove-Item $zipPath -Force
            }
            if (Test-Path $extractPath) {
                Remove-Item $extractPath -Recurse -Force
            }
        }
        catch {
            Write-Log "Warning: Could not clean up temporary files: $_" -Level "WARN"
        }
    }
}
#endregion

#region Configuration Functions
function Update-WindowsTerminalConfig {
    <#
    .SYNOPSIS
        Configure Windows Terminal to use FiraCode Nerd Font
    .DESCRIPTION
        Updates Windows Terminal settings to use FiraCode Nerd Font
    .OUTPUTS
        System.Boolean - True if configuration succeeded
    .EXAMPLE
        Update-WindowsTerminalConfig
    #>
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param()
    
    Write-Log "Configuring Windows Terminal font settings" -Level "INFO"
    
    $settingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    
    if (-not (Test-Path $settingsPath)) {
        Write-Log "Windows Terminal settings.json not found. Please launch Windows Terminal at least once." -Level "WARN"
        return $false
    }
    
    try {
        # Create backup
        $backupPath = New-ConfigurationBackup -FilePath $settingsPath -BackupName "windows-terminal-settings"
        
        # Read and parse settings
        $settingsContent = Get-Content $settingsPath -Raw -Encoding UTF8
        $settings = $settingsContent | ConvertFrom-Json
        
        # Update default profile font
        if ($settings.defaultProfile) {
            $defaultProfile = $settings.profiles.list | Where-Object { $_.guid -eq $settings.defaultProfile }
            if ($defaultProfile) {
                $defaultProfile.font = @{
                    face = "FiraCode Nerd Font"
                    size = 10
                }
                Write-Log "Updated default profile font configuration" -Level "SUCCESS"
            }
        }
        
        # Update all profiles if no default is set
        if (-not $settings.defaultProfile -or -not $defaultProfile) {
            foreach ($profile in $settings.profiles.list) {
                if (-not $profile.font) {
                    $profile | Add-Member -NotePropertyName "font" -NotePropertyValue @{} -Force
                }
                $profile.font.face = "FiraCode Nerd Font"
            }
            Write-Log "Updated font for all terminal profiles" -Level "SUCCESS"
        }
        
        # Write settings back
        $settings | ConvertTo-Json -Depth 20 | Set-Content -Path $settingsPath -Encoding UTF8
        Write-Log "Windows Terminal configuration updated successfully" -Level "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Error updating Windows Terminal configuration: $_" -Level "ERROR"
        
        # Restore backup if available
        if ($backupPath -and (Test-Path $backupPath)) {
            try {
                Copy-Item -Path $backupPath -Destination $settingsPath -Force
                Write-Log "Restored Windows Terminal settings from backup" -Level "INFO"
            }
            catch {
                Write-Log "Failed to restore backup: $_" -Level "ERROR"
            }
        }
        return $false
    }
}

function Update-VSCodeConfig {
    <#
    .SYNOPSIS
        Configure VS Code to use FiraCode Nerd Font
    .DESCRIPTION
        Updates VS Code settings to use FiraCode Nerd Font
    .OUTPUTS
        System.Boolean - True if configuration succeeded
    .EXAMPLE
        Update-VSCodeConfig
    #>
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param()
    
    Write-Log "Configuring VS Code font settings" -Level "INFO"
    
    $possiblePaths = @(
        "$env:APPDATA\Code\User\settings.json",
        "$env:APPDATA\Code - Insiders\User\settings.json"
    )
    
    $settingsPath = $possiblePaths | Where-Object { Test-Path $_ } | Select-Object -First 1
    
    if (-not $settingsPath) {
        Write-Log "VS Code settings.json not found. Please launch VS Code at least once." -Level "WARN"
        return $false
    }
    
    try {
        # Create backup
        $backupPath = New-ConfigurationBackup -FilePath $settingsPath -BackupName "vscode-settings"
        
        # Read existing settings or create new
        $settings = @{}
        if (Test-Path $settingsPath) {
            $settingsContent = Get-Content $settingsPath -Raw -Encoding UTF8
            if ($settingsContent.Trim()) {
                $settings = $settingsContent | ConvertFrom-Json
            }
        }
        
        # Update font settings
        $settings."terminal.integrated.fontFamily" = "FiraCode Nerd Font"
        $settings."editor.fontFamily" = "FiraCode Nerd Font, Consolas, 'Courier New', monospace"
        $settings."editor.fontLigatures" = $true
        
        # Ensure directory exists
        $settingsDir = Split-Path $settingsPath -Parent
        if (-not (Test-Path $settingsDir)) {
            New-Item -Path $settingsDir -ItemType Directory -Force | Out-Null
        }
        
        # Write settings
        $settings | ConvertTo-Json -Depth 20 | Set-Content -Path $settingsPath -Encoding UTF8
        Write-Log "VS Code configuration updated successfully" -Level "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Error updating VS Code configuration: $_" -Level "ERROR"
        
        # Restore backup if available
        if ($backupPath -and (Test-Path $backupPath)) {
            try {
                Copy-Item -Path $backupPath -Destination $settingsPath -Force
                Write-Log "Restored VS Code settings from backup" -Level "INFO"
            }
            catch {
                Write-Log "Failed to restore backup: $_" -Level "ERROR"
            }
        }
        return $false
    }
}
#endregion

#region Main Function
function Install-WSLEnvironment {
    <#
    .SYNOPSIS
        Main function to install and configure WSL development environment
    .DESCRIPTION
        Orchestrates the complete WSL development environment setup including distribution installation,
        font installation, Starship prompt setup, and application configuration
    .PARAMETER DistroName
        The WSL distribution name to install/configure (default: Ubuntu)
    .PARAMETER SkipFontInstall
        Skip the FiraCode Nerd Font installation step
    .PARAMETER SkipStarship
        Skip the Starship prompt installation in WSL
    .PARAMETER LogPath
        Custom path for log file (default: %TEMP%\configure-wsl.log)
    .OUTPUTS
        System.Int32 - Exit code (0 for success, 1 for failure)
    .EXAMPLE
        Install-WSLEnvironment
    .EXAMPLE
        Install-WSLEnvironment -DistroName "Ubuntu-22.04" -LogPath "C:\Logs\wsl-setup.log"
    #>
    [CmdletBinding()]
    [OutputType([System.Int32])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$DistroName = "Ubuntu",
        
        [Parameter(Mandatory = $false)]
        [switch]$SkipFontInstall,
        
        [Parameter(Mandatory = $false)]
        [switch]$SkipStarship,
        
        [Parameter(Mandatory = $false)]
        [string]$LogPath = "$env:TEMP\configure-wsl.log"
    )
    
    try {
        # Initialize logging
        Initialize-Logging -LogPath $LogPath
        
        # Check administrator privileges
        if (-not (Test-IsAdministrator)) {
            Write-Log "This module requires Administrator privileges. Please restart PowerShell as Administrator." -Level "ERROR"
            return 1
        }
        
        Write-Log "Starting WSL Development Environment Configuration" -Level "INFO"
        Write-Log "Parameters: DistroName=$DistroName, SkipFontInstall=$SkipFontInstall, SkipStarship=$SkipStarship" -Level "INFO"
        
        # Validate prerequisites
        $prereqsResult = Test-Prerequisites
        if (-not $prereqsResult) {
            Write-Log "Prerequisites check failed. Please resolve the issues and try again." -Level "ERROR"
            return 1
        }
        
        # Step 1: Install WSL Distribution
        Write-Log "=== Step 1: WSL Distribution Setup ===" -Level "INFO"
        $wslResult = Install-WSLDistribution -DistroName $DistroName
        if (-not $wslResult) {
            Write-Log "WSL installation failed. Please check the logs and try again." -Level "ERROR"
            return 1
        }
        
        # Step 2: Install FiraCode Font (if not skipped)
        if (-not $SkipFontInstall) {
            Write-Log "=== Step 2: FiraCode Nerd Font Installation ===" -Level "INFO"
            $fontResult = Install-FiraCodeFont
            if (-not $fontResult) {
                Write-Log "Font installation failed, but continuing with other steps" -Level "WARN"
            }
        }
        else {
            Write-Log "=== Step 2: Skipping Font Installation ===" -Level "INFO"
        }
        
        # Step 3: Install Starship (if not skipped)
        if (-not $SkipStarship) {
            Write-Log "=== Step 3: Starship Prompt Installation ===" -Level "INFO"
            $starshipResult = Install-StarshipInWSL -DistroName $DistroName
            if (-not $starshipResult) {
                Write-Log "Starship installation failed, but continuing with other steps" -Level "WARN"
            }
        }
        else {
            Write-Log "=== Step 3: Skipping Starship Installation ===" -Level "INFO"
        }
        
        # Step 4: Configure Applications
        Write-Log "=== Step 4: Application Configuration ===" -Level "INFO"
        
        if (-not $SkipFontInstall) {
            $terminalResult = Update-WindowsTerminalConfig
            $vscodeResult = Update-VSCodeConfig
            
            if (-not $terminalResult) {
                Write-Log "Windows Terminal configuration failed" -Level "WARN"
            }
            if (-not $vscodeResult) {
                Write-Log "VS Code configuration failed" -Level "WARN"
            }
        }
        
        # Success message
        Write-Log "=== Configuration Complete ===" -Level "SUCCESS"
        Write-Log "Your WSL development environment has been configured successfully!" -Level "SUCCESS"
        Write-Log "Log file saved to: $script:LogPath" -Level "INFO"
        
        if (Test-Path $script:BackupDirectory) {
            Write-Log "Configuration backups saved to: $script:BackupDirectory" -Level "INFO"
        }
        
        Write-Log "Next steps:" -Level "INFO"
        Write-Log "1. Restart Windows Terminal and VS Code to apply font changes" -Level "INFO"
        Write-Log "2. Launch your WSL distribution and enjoy your new development environment!" -Level "INFO"
        
        return 0
    }
    catch {
        Write-Log "Critical error during script execution: $_" -Level "ERROR"
        Write-Log "Stack trace: $($_.ScriptStackTrace)" -Level "ERROR"
        return 1
    }
}
#endregion

# Export module functions
Export-ModuleMember -Function @(
    'Install-WSLEnvironment',
    'Test-WSLInstallation',
    'Install-WSLDistribution',
    'Install-FiraCodeFont',
    'Install-StarshipInWSL',
    'Update-WindowsTerminalConfig',
    'Update-VSCodeConfig',
    'Test-Prerequisites',
    'Test-IsAdministrator',
    'Write-Log',
    'Initialize-Logging'
)