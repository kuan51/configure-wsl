<#
.SYNOPSIS
    Configure WSL Development Environment
    
.DESCRIPTION
    Sets up Ubuntu WSL, FiraCode Nerd Font, Starship prompt, and configures Windows Terminal & VS Code
    for an optimal development environment. This script requires Administrator privileges.
    
.PARAMETER DistroName
    The WSL distribution name to install/configure (default: Ubuntu)
    
.PARAMETER SkipFontInstall
    Skip the FiraCode Nerd Font installation step
    
.PARAMETER SkipStarship
    Skip the Starship prompt installation in WSL
    
.PARAMETER LogPath
    Custom path for log file (default: %TEMP%\configure-wsl.log)
    
.EXAMPLE
    .\configure-wsl.ps1
    Run with default settings
    
.EXAMPLE
    .\configure-wsl.ps1 -DistroName "Ubuntu-22.04" -LogPath "C:\Logs\wsl-setup.log"
    Run with custom distribution and log path
    
.NOTES
    Author: WSL Configuration Script
    Version: 2.0
    Requires: PowerShell 5.1+ and Administrator privileges
#>

[CmdletBinding()]
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

#Requires -RunAsAdministrator

# Set strict error handling
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue" # Suppress progress bars for cleaner output

# Global variables
$script:LogPath = $LogPath
$script:BackupDirectory = "$env:TEMP\wsl-config-backups-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

#region Logging Functions
function Write-Log {
    <#
    .SYNOPSIS
        Write message to log file and console
    #>
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
        Add-Content -Path $script:LogPath -Value $logEntry -Encoding UTF8 -ErrorAction SilentlyContinue
    }
    catch {
        # Fallback if logging fails
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
    #>
    try {
        $logDir = Split-Path $script:LogPath -Parent
        if (-not (Test-Path $logDir)) {
            New-Item -Path $logDir -ItemType Directory -Force | Out-Null
        }
        
        $startMessage = "=== WSL Configuration Script Started ==="
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
function Test-Prerequisites {
    <#
    .SYNOPSIS
        Validate system prerequisites
    #>
    Write-Log "Checking system prerequisites..." -Level "INFO"
    
    # Check Windows version
    $windowsVersion = [System.Environment]::OSVersion.Version
    if ($windowsVersion.Major -lt 10) {
        throw "Windows 10 or later is required for WSL"
    }
    
    # Check WSL availability
    try {
        $wslHelp = wsl.exe --help 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "WSL is not available. Please enable WSL feature first."
        }
    }
    catch {
        throw "WSL command not found. Please install WSL first."
    }
    
    # Check internet connectivity
    try {
        $testConnection = Test-NetConnection -ComputerName "github.com" -Port 443 -InformationLevel Quiet -WarningAction SilentlyContinue
        if (-not $testConnection) {
            throw "Internet connectivity required for downloads"
        }
    }
    catch {
        Write-Log "Warning: Could not verify internet connectivity" -Level "WARN"
    }
    
    Write-Log "Prerequisites check completed successfully" -Level "SUCCESS"
}

function Test-IsAdministrator {
    <#
    .SYNOPSIS
        Check if running as Administrator
    #>
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
#endregion

#region Backup Functions
function New-ConfigurationBackup {
    <#
    .SYNOPSIS
        Create backup of configuration files before modification
    #>
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
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$DistroName
    )
    
    Write-Log "Checking for WSL distribution: $DistroName" -Level "INFO"
    
    try {
        $existingDistros = wsl.exe --list --quiet 2>$null | Where-Object { $_ -ne "" -and $_.Trim() -ne "" }
        
        if ($existingDistros -contains $DistroName) {
            Write-Log "Distribution '$DistroName' is already installed" -Level "SUCCESS"
            return $true
        }
        
        Write-Log "Installing WSL distribution: $DistroName" -Level "INFO"
        
        # Use wsl --install for better compatibility
        $installProcess = Start-Process -FilePath "wsl.exe" -ArgumentList "--install", "-d", $DistroName -Wait -PassThru -NoNewWindow
        
        if ($installProcess.ExitCode -eq 0) {
            Write-Log "WSL distribution '$DistroName' installation initiated successfully" -Level "SUCCESS"
            Write-Log "Please complete the initial setup (username/password) when prompted" -Level "INFO"
            
            # Wait for user to complete setup
            Write-Host "Press any key after completing the WSL setup..." -ForegroundColor Yellow
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            
            return $true
        }
        else {
            Write-Log "WSL installation failed with exit code: $($installProcess.ExitCode)" -Level "ERROR"
            return $false
        }
    }
    catch {
        Write-Log "Error during WSL installation: $_" -Level "ERROR"
        return $false
    }
}

function Install-StarshipInWSL {
    <#
    .SYNOPSIS
        Install Starship prompt in WSL
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$DistroName
    )
    
    Write-Log "Installing Starship and dependencies in WSL: $DistroName" -Level "INFO"
    
    $wslScript = @'
#!/bin/bash
set -e

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
        $tempScript = [System.IO.Path]::GetTempFileName() + ".sh"
        $wslScript | Out-File -FilePath $tempScript -Encoding UTF8
        
        $wslProcess = Start-Process -FilePath "wsl.exe" -ArgumentList "-d", $DistroName, "bash", $tempScript -Wait -PassThru -NoNewWindow
        
        Remove-Item $tempScript -Force -ErrorAction SilentlyContinue
        
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
        Install FiraCode Nerd Font with modern approach and cleanup
    #>
    Write-Log "Installing FiraCode Nerd Font" -Level "INFO"
    
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
                # Use Add-Type for font installation (modern approach)
                $fontBytes = [System.IO.File]::ReadAllBytes($fontFile.FullName)
                $fontCollection = New-Object System.Drawing.Text.PrivateFontCollection
                $fontCollection.AddMemoryFont($fontBytes, $fontBytes.Length)
                
                # Copy to Fonts directory
                $fontsDirectory = [Environment]::GetFolderPath("Fonts")
                $destinationPath = Join-Path $fontsDirectory $fontFile.Name
                
                if (-not (Test-Path $destinationPath)) {
                    Copy-Item -Path $fontFile.FullName -Destination $destinationPath -Force
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
    #>
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
    #>
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

#region Main Script
function Main {
    <#
    .SYNOPSIS
        Main script execution function
    #>
    try {
        # Initialize logging
        Initialize-Logging
        
        Write-Log "Starting WSL Development Environment Configuration" -Level "INFO"
        Write-Log "Parameters: DistroName=$DistroName, SkipFontInstall=$SkipFontInstall, SkipStarship=$SkipStarship" -Level "INFO"
        
        # Validate prerequisites
        Test-Prerequisites
        
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

# Script entry point
if (-not (Test-IsAdministrator)) {
    Write-Error "This script must be run as Administrator. Please restart PowerShell as Administrator and try again."
    exit 1
}

# Execute main function
$exitCode = Main
exit $exitCode
#endregion
