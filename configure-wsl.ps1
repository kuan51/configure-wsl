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
    [string]$LogPath = "$env:TEMP\configure-wsl.log",
    
    [Parameter(Mandatory = $false)]
    [string]$WSLUsername,
    
    [Parameter(Mandatory = $false)]
    [SecureString]$WSLPassword
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
    
    # Enhanced Windows version check for WSL2
    $buildNumber = [System.Environment]::OSVersion.Version.Build
    if ($windowsVersion.Major -eq 10 -and $buildNumber -lt 19041) {
        Write-Log "Warning: WSL2 requires Windows 10 version 2004 (build 19041) or later. Current build: $buildNumber" -Level "WARN"
        Write-Log "WSL1 may still work, but WSL2 is recommended for better performance" -Level "WARN"
    }
    
    # Check WSL installation status
    $wslStatus = Test-WSLInstallation
    if ($wslStatus.IsInstalled -eq $false) {
        Write-Log "WSL is not installed. Attempting automatic installation..." -Level "WARN"
        $installResult = Install-WSLFeature
        if (-not $installResult) {
            throw "Failed to install WSL. Please install WSL manually using 'wsl --install' in an elevated PowerShell session."
        }
        Write-Log "WSL installation completed. A system restart may be required." -Level "SUCCESS"
    }
    elseif ($wslStatus.IsEnabled -eq $false) {
        Write-Log "WSL feature is installed but not enabled. Attempting to enable..." -Level "WARN"
        $enableResult = Enable-WSLFeature
        if (-not $enableResult) {
            throw "Failed to enable WSL feature. Please enable it manually in Windows Features."
        }
    }
    else {
        Write-Log "WSL is properly installed and available (Version: $($wslStatus.Version))" -Level "SUCCESS"
    }
    
    # Check internet connectivity
    try {
        $testConnection = Test-NetConnection -ComputerName "github.com" -Port 443 -InformationLevel Quiet -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
        if (-not $testConnection) {
            throw "Internet connectivity required for downloads"
        }
    }
    catch {
        Write-Log "Warning: Could not verify internet connectivity" -Level "WARN"
    }
    
    Write-Log "Prerequisites check completed successfully" -Level "SUCCESS"
}

function Test-WSLInstallation {
    <#
    .SYNOPSIS
        Test if WSL is installed and properly configured
    .OUTPUTS
        PSCustomObject with IsInstalled, IsEnabled, and Version properties
    #>
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

function Install-WSLFeature {
    <#
    .SYNOPSIS
        Install WSL using the modern wsl --install command
    .OUTPUTS
        Boolean indicating success
    #>
    Write-Log "Installing WSL feature..." -Level "INFO"
    
    try {
        # Use the modern wsl --install command (Windows 10 2004+)
        $installProcess = Start-Process -FilePath "wsl.exe" -ArgumentList "--install", "--no-distribution" -Wait -PassThru -NoNewWindow -Verb RunAs
        
        if ($installProcess.ExitCode -eq 0) {
            Write-Log "WSL installation completed successfully" -Level "SUCCESS"
            Write-Log "Note: A system restart may be required before WSL can be used" -Level "INFO"
            return $true
        }
        else {
            Write-Log "WSL installation failed with exit code: $($installProcess.ExitCode)" -Level "ERROR"
            
            # Fallback: Try enabling WSL feature via DISM
            Write-Log "Attempting fallback installation via DISM..." -Level "INFO"
            return Install-WSLFeatureViaDISM
        }
    }
    catch {
        Write-Log "Error during WSL installation: $_" -Level "ERROR"
        
        # Fallback: Try enabling WSL feature via DISM
        Write-Log "Attempting fallback installation via DISM..." -Level "INFO"
        return Install-WSLFeatureViaDISM
    }
}

function Install-WSLFeatureViaDISM {
    <#
    .SYNOPSIS
        Install WSL using DISM (fallback method)
    .OUTPUTS
        Boolean indicating success
    #>
    try {
        Write-Log "Installing WSL via DISM (Windows Features)..." -Level "INFO"
        
        # Enable WSL feature
        $wslResult = Enable-WindowsOptionalFeature -Online -FeatureName "Microsoft-Windows-Subsystem-Linux" -All -NoRestart
        
        # Enable Virtual Machine Platform for WSL2 (if available)
        try {
            $vmResult = Enable-WindowsOptionalFeature -Online -FeatureName "VirtualMachinePlatform" -All -NoRestart -ErrorAction SilentlyContinue
            if ($vmResult.RestartNeeded) {
                Write-Log "Virtual Machine Platform enabled (WSL2 support)" -Level "SUCCESS"
            }
        }
        catch {
            Write-Log "Virtual Machine Platform not available or already enabled" -Level "INFO"
        }
        
        if ($wslResult.RestartNeeded) {
            Write-Log "WSL feature installation completed" -Level "SUCCESS"
            Write-Log "IMPORTANT: A system restart is required before WSL can be used" -Level "WARN"
            Write-Log "Please restart your computer and run this script again" -Level "WARN"
            return $true
        }
        else {
            Write-Log "WSL feature enabled successfully" -Level "SUCCESS"
            return $true
        }
    }
    catch {
        Write-Log "Failed to install WSL via DISM: $_" -Level "ERROR"
        return $false
    }
}

function Enable-WSLFeature {
    <#
    .SYNOPSIS
        Enable already installed WSL feature
    .OUTPUTS
        Boolean indicating success
    #>
    try {
        Write-Log "Enabling WSL feature..." -Level "INFO"
        
        $result = Enable-WindowsOptionalFeature -Online -FeatureName "Microsoft-Windows-Subsystem-Linux" -All -NoRestart
        
        if ($result.RestartNeeded) {
            Write-Log "WSL feature enabled. A restart may be required." -Level "SUCCESS"
        }
        else {
            Write-Log "WSL feature enabled successfully" -Level "SUCCESS"
        }
        
        return $true
    }
    catch {
        Write-Log "Failed to enable WSL feature: $_" -Level "ERROR"
        return $false
    }
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

#region Credential Functions
function Get-WSLCredentials {
    <#
    .SYNOPSIS
        Collect WSL user credentials for automated setup
    #>
    param(
        [Parameter(Mandatory = $false)]
        [string]$Username,
        
        [Parameter(Mandatory = $false)]
        [SecureString]$Password
    )
    
    $credentials = @{
        Username = $Username
        Password = $Password
    }
    
    # Collect username if not provided
    if (-not $credentials.Username) {
        Write-Host ""
        Write-Host "WSL User Setup" -ForegroundColor Cyan
        Write-Host "===============" -ForegroundColor Cyan
        Write-Host "Please provide credentials for your WSL user account." -ForegroundColor Yellow
        Write-Host "This will be used to create your default user in the WSL distribution." -ForegroundColor Yellow
        Write-Host ""
        
        do {
            $credentials.Username = Read-Host "Enter WSL username (lowercase, no spaces)"
            if ([string]::IsNullOrWhiteSpace($credentials.Username)) {
                Write-Host "Username cannot be empty. Please try again." -ForegroundColor Red
            }
            elseif ($credentials.Username -match '[^a-z0-9]') {
                Write-Host "Username should contain only lowercase letters and numbers. Please try again." -ForegroundColor Red
                $credentials.Username = $null
            }
        } while ([string]::IsNullOrWhiteSpace($credentials.Username))
    }
    
    # Collect password if not provided
    if (-not $credentials.Password) {
        do {
            $credentials.Password = Read-Host "Enter password for $($credentials.Username)" -AsSecureString
            $confirmPassword = Read-Host "Confirm password" -AsSecureString
            
            # Convert to plain text for comparison
            $plainPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($credentials.Password))
            $plainConfirm = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($confirmPassword))
            
            if ($plainPassword -ne $plainConfirm) {
                Write-Host "Passwords do not match. Please try again." -ForegroundColor Red
                $credentials.Password = $null
            }
            elseif ($plainPassword.Length -lt 1) {
                Write-Host "Password cannot be empty. Please try again." -ForegroundColor Red
                $credentials.Password = $null
            }
            
            # Clear plain text passwords from memory
            $plainPassword = $null
            $plainConfirm = $null
        } while (-not $credentials.Password)
        
        Write-Host ""
        Write-Host "Credentials collected successfully. Proceeding with automated setup..." -ForegroundColor Green
        Write-Host ""
    }
    
    return $credentials
}
#endregion

#region WSL Functions
function Get-WSLErrorMessage {
    <#
    .SYNOPSIS
        Translate WSL error codes to helpful messages
    #>
    param(
        [Parameter(Mandatory = $true)]
        [int]$ExitCode,
        
        [string]$ErrorOutput = ""
    )
    
    switch ($ExitCode) {
        -1 {
            if ($ErrorOutput -match "0x8000000d") {
                return "Another WSL operation is in progress. Please wait for it to complete and try again."
            }
            elseif ($ErrorOutput -match "0x80370102") {
                return "Virtual Machine Platform is not enabled. Run 'Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform' and restart."
            }
            elseif ($ErrorOutput -match "0x80370114") {
                return "WSL 2 requires an update to its kernel component. Visit https://aka.ms/wsl2kernel"
            }
            return "WSL operation failed. Check if WSL is properly installed and try restarting your computer."
        }
        1 {
            return "The requested distribution is not available or WSL is not properly configured."
        }
        default {
            return "WSL operation failed with exit code: $ExitCode"
        }
    }
}

function Test-WSLDistributionState {
    <#
    .SYNOPSIS
        Check WSL distribution state and handle stuck operations
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$DistroName
    )
    
    Write-Log "Checking WSL distribution state for '$DistroName'..." -Level "INFO"
    
    try {
        $distroInfo = & wsl.exe --list --all --verbose 2>&1 | Select-String $DistroName
        
        if ($distroInfo -match "Uninstalling") {
            Write-Log "Distribution '$DistroName' is being uninstalled. Waiting for completion..." -Level "WARN"
            
            # Wait up to 60 seconds for uninstallation
            $waited = 0
            while ($waited -lt 60) {
                Start-Sleep -Seconds 5
                $waited += 5
                
                $currentInfo = & wsl.exe --list --all --verbose 2>&1 | Select-String $DistroName
                if (-not $currentInfo -or $currentInfo -notmatch "Uninstalling") {
                    Write-Log "Uninstallation completed" -Level "INFO"
                    return $true
                }
                
                Write-Log "Still waiting... ($waited/60 seconds)" -Level "INFO"
            }
            
            # Force unregister if still stuck
            Write-Log "Forcing unregistration of stuck distribution..." -Level "WARN"
            & wsl.exe --unregister $DistroName 2>$null
            Start-Sleep -Seconds 3
            return $true
        }
        elseif ($distroInfo -match "Installing") {
            Write-Log "Distribution '$DistroName' is being installed by another process" -Level "ERROR"
            return $false
        }
        
        return $true
    }
    catch {
        Write-Log "Error checking distribution state: $_" -Level "WARN"
        return $true  # Continue anyway
    }
}

function Install-WSLDistribution {
    <#
    .SYNOPSIS
        Install WSL distribution if not present
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$DistroName,
        
        [Parameter(Mandatory = $true)]
        [string]$Username,
        
        [Parameter(Mandatory = $true)]
        [SecureString]$Password
    )
    
    Write-Log "Checking for WSL distribution: $DistroName" -Level "INFO"
    
    try {
        # First check if distribution is in a stuck state
        if (-not (Test-WSLDistributionState -DistroName $DistroName)) {
            Write-Log "Cannot proceed: Distribution is in an invalid state" -Level "ERROR"
            return $false
        }
        
        # Verify WSL is working
        $wslTest = & wsl.exe --status 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Log "WSL is not ready. Testing basic functionality..." -Level "WARN"
            
            # Try a simple command to verify WSL works
            $wslVersion = & wsl.exe --version 2>$null
            if ($LASTEXITCODE -ne 0) {
                throw "WSL is installed but not functioning properly. You may need to restart your computer."
            }
        }
        
        # Check existing distributions with state information
        $existingDistros = @()
        $distroStates = @{}
        try {
            # Get detailed distribution information including state
            $distroListVerbose = & wsl.exe --list --all --verbose 2>$null
            if ($LASTEXITCODE -eq 0 -and $distroListVerbose) {
                # Parse the verbose output to get distribution states
                $lines = $distroListVerbose | Select-Object -Skip 1 # Skip header
                foreach ($line in $lines) {
                    if ($line -match '^\s*\*?\s*(.+?)\s+(Running|Stopped|Installing|Uninstalling|Converting)\s+') {
                        $name = $Matches[1].Trim()
                        $state = $Matches[2].Trim()
                        $distroStates[$name] = $state
                        $existingDistros += $name
                    }
                }
            }
            
            # Fallback to simple list if verbose fails
            if ($existingDistros.Count -eq 0) {
                $distroList = & wsl.exe --list --quiet 2>$null
                if ($LASTEXITCODE -eq 0 -and $distroList) {
                    $existingDistros = $distroList | Where-Object { $_ -ne "" -and $_.Trim() -ne "" } | ForEach-Object { $_.Trim() }
                }
            }
        }
        catch {
            Write-Log "Could not list existing distributions, proceeding with installation" -Level "WARN"
        }
        
        # Check if distribution already exists and its state
        $distroExists = $false
        $distroState = $null
        foreach ($distro in $existingDistros) {
            if ($distro -eq $DistroName -or $distro -like "*$DistroName*") {
                $distroExists = $true
                $distroState = $distroStates[$distro]
                break
            }
        }
        
        if ($distroExists) {
            # Check distribution state
            if ($distroState -eq "Uninstalling") {
                Write-Log "Distribution '$DistroName' is currently being uninstalled. Waiting for completion..." -Level "WARN"
                
                # Wait for uninstallation to complete (max 60 seconds)
                $waitTime = 0
                $maxWaitTime = 60
                while ($waitTime -lt $maxWaitTime) {
                    Start-Sleep -Seconds 5
                    $waitTime += 5
                    
                    # Check if still uninstalling
                    $currentState = & wsl.exe --list --all --verbose 2>$null | Select-String $DistroName
                    if (-not $currentState -or $currentState -notmatch "Uninstalling") {
                        Write-Log "Uninstallation completed" -Level "INFO"
                        $distroExists = $false
                        break
                    }
                    
                    Write-Log "Still waiting for uninstallation to complete... ($waitTime/$maxWaitTime seconds)" -Level "INFO"
                }
                
                if ($distroExists) {
                    Write-Log "Uninstallation is taking too long. Attempting to force unregister..." -Level "WARN"
                    & wsl.exe --unregister $DistroName 2>$null
                    Start-Sleep -Seconds 5
                    $distroExists = $false
                }
            }
            elseif ($distroState -eq "Installing") {
                Write-Log "Distribution '$DistroName' is currently being installed by another process" -Level "ERROR"
                return $false
            }
            else {
                Write-Log "Distribution '$DistroName' is already installed (State: $distroState)" -Level "SUCCESS"
                
                # Verify user exists and is properly configured
                Write-Log "Verifying existing user configuration..." -Level "INFO"
                $userCheck = & wsl.exe -d $DistroName bash -c "id $Username" 2>$null
                if ($LASTEXITCODE -ne 0) {
                    Write-Log "User '$Username' does not exist in existing distribution. Creating user..." -Level "WARN"
                    return Set-WSLDefaultUser -DistroName $DistroName -Username $Username -Password $Password
                }
                else {
                    Write-Log "User '$Username' already exists in distribution" -Level "SUCCESS"
                    return $true
                }
            }
        }
        
        Write-Log "Installing WSL distribution: $DistroName" -Level "INFO"
        Write-Log "This may take several minutes..." -Level "INFO"
        
        # Use wsl --install with --no-launch for automation (prevents interactive setup)
        $installArgs = @("--install", "-d", $DistroName, "--no-launch")
        Write-Log "Executing: wsl.exe $($installArgs -join ' ')" -Level "INFO"
        
        $installProcess = Start-Process -FilePath "wsl.exe" -ArgumentList $installArgs -Wait -PassThru -NoNewWindow
        
        if ($installProcess.ExitCode -eq 0) {
            Write-Log "WSL distribution '$DistroName' installation completed successfully" -Level "SUCCESS"
            
            # Wait for installation to complete and WSL to be ready
            Write-Log "Waiting for WSL distribution to be ready..." -Level "INFO"
            Start-Sleep -Seconds 10
            
            # Set up the user account immediately to prevent interactive prompts
            Write-Log "Setting up automated user account..." -Level "INFO"
            $userSetupSuccess = Set-WSLDefaultUser -DistroName $DistroName -Username $Username -Password $Password
            
            if (-not $userSetupSuccess) {
                Write-Log "Failed to set up user account automatically" -Level "ERROR"
                return $false
            }
            
            # Initialize the distribution after user setup
            Write-Log "Initializing distribution with essential packages..." -Level "INFO"
            try {
                # Create a temporary script for automated initial setup (run as root to avoid sudo prompts)
                $setupScript = @'
#!/bin/bash
# Automated WSL distribution setup
echo "Setting up WSL distribution..."

# Update package lists (suppress interactive prompts)
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq

# Install essential packages
apt-get install -y curl wget git unzip

echo "WSL distribution setup completed"
'@
                
                # Run the setup in WSL as root to avoid sudo prompts
                $setupResult = $setupScript | & wsl.exe -d $DistroName --user root bash
                if ($LASTEXITCODE -eq 0) {
                    Write-Log "Distribution initialized successfully" -Level "SUCCESS"
                }
                else {
                    Write-Log "Warning: Distribution initialization had issues but continuing" -Level "WARN"
                }
            }
            catch {
                Write-Log "Warning: Could not run automated setup: $_" -Level "WARN"
            }
            
            # Verify installation
            try {
                $verifyDistros = & wsl.exe --list --quiet 2>$null
                if ($verifyDistros -and ($verifyDistros -contains $DistroName -or $verifyDistros -like "*$DistroName*")) {
                    Write-Log "Distribution installation verified successfully" -Level "SUCCESS"
                }
                else {
                    Write-Log "Warning: Could not verify distribution installation" -Level "WARN"
                }
            }
            catch {
                Write-Log "Warning: Could not verify distribution installation: $_" -Level "WARN"
            }
            
            return $true
        }
        else {
            # Capture error output for better diagnostics
            $errorOutput = & wsl.exe --install -d $DistroName --no-launch 2>&1 | Out-String
            $errorMessage = Get-WSLErrorMessage -ExitCode $installProcess.ExitCode -ErrorOutput $errorOutput
            
            Write-Log "WSL distribution installation failed: $errorMessage" -Level "ERROR"
            
            # Check if error is due to ongoing operation
            if ($installProcess.ExitCode -eq -1 -and $errorOutput -match "0x8000000d") {
                # Try to clean up the stuck operation
                Write-Log "Attempting to clean up stuck WSL operation..." -Level "INFO"
                
                $cleanupResult = Test-WSLDistributionState -DistroName $DistroName
                if ($cleanupResult) {
                    Write-Log "Retrying installation after cleanup..." -Level "INFO"
                    
                    # Retry installation once
                    $retryProcess = Start-Process -FilePath "wsl.exe" -ArgumentList $installArgs -Wait -PassThru -NoNewWindow
                    if ($retryProcess.ExitCode -eq 0) {
                        Write-Log "WSL distribution '$DistroName' installation completed successfully on retry" -Level "SUCCESS"
                        
                        # Continue with user setup
                        Start-Sleep -Seconds 10
                        $userSetupSuccess = Set-WSLDefaultUser -DistroName $DistroName -Username $Username -Password $Password
                        
                        if (-not $userSetupSuccess) {
                            Write-Log "Failed to set up user account automatically" -Level "ERROR"
                            return $false
                        }
                        
                        return $true
                    }
                }
            }
            
            # Try alternative installation method for older systems
            Write-Log "Attempting alternative installation method..." -Level "INFO"
            return Install-WSLDistributionAlternative -DistroName $DistroName
        }
    }
    catch {
        Write-Log "Error during WSL distribution installation: $_" -Level "ERROR"
        
        # If it's a specific WSL error, provide more context
        if ($_.Exception.Message -match "0x8000000d") {
            Write-Log "This error typically occurs when another WSL operation is in progress." -Level "ERROR"
            Write-Log "Please close all WSL-related windows and try again." -Level "ERROR"
            Write-Log "If the problem persists, restart your computer." -Level "ERROR"
            return $false
        }
        
        Write-Log "Attempting alternative installation method..." -Level "INFO"
        return Install-WSLDistributionAlternative -DistroName $DistroName
    }
}

function Set-WSLWelcomeMessage {
    <#
    .SYNOPSIS
        Set up a welcome message with Linux penguin ASCII art for WSL
    .DESCRIPTION
        Creates a welcome message with penguin ASCII art that displays when starting a new WSL terminal session
    .PARAMETER DistroName
        Name of the WSL distribution
    .PARAMETER Username
        Username to configure the welcome message for
    .EXAMPLE
        Set-WSLWelcomeMessage -DistroName "Ubuntu" -Username "myuser"
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$DistroName,
        
        [Parameter(Mandatory = $true)]
        [string]$Username
    )
    
    try {
        # Create simple bash script to add welcome message
        $bashScript = @'
#!/bin/bash

# Check if welcome message is already in bashrc
if ! grep -q "Welcome Viber" ~/.bashrc 2>/dev/null; then
    echo "" >> ~/.bashrc
    echo "# Custom welcome message" >> ~/.bashrc
    echo "if [ -t 1 ]; then" >> ~/.bashrc
    echo '    echo -e "\033[1;36m"' >> ~/.bashrc
    echo '    echo "        a8888b.                    Welcome Viber, let'\''s get to work!"' >> ~/.bashrc
    echo '    echo "             d888888b."' >> ~/.bashrc
    echo '    echo "             8P\"YP\"Y88              Your WSL Ubuntu development environment"' >> ~/.bashrc
    echo '    echo "             8|o||o|88              is ready and configured!"' >> ~/.bashrc
    echo '    echo "             8'\''    .88"' >> ~/.bashrc
    echo '    echo "             8\`._.\'' Y8.             Features: FiraCode Font, Starship, Dev Tools"' >> ~/.bashrc
    echo '    echo "            d/      \`8b."' >> ~/.bashrc
    echo '    echo "          .dP   .     Y8b.          Tips: '\''code .\'' for VS Code, '\''git'\'' for version control"' >> ~/.bashrc
    echo '    echo "         d8:'\''   \"   \`::88b."' >> ~/.bashrc
    echo '    echo "        d8\"           \`Y88b         Happy coding!"' >> ~/.bashrc
    echo '    echo "       :8P     '\''       :888"' >> ~/.bashrc
    echo '    echo "        8a.    :      _a88P"' >> ~/.bashrc
    echo '    echo "      ._/\"Yaa_ :    .| 88P|"' >> ~/.bashrc
    echo '    echo " jgs  \\    YP\"      \`| 8P  \`."' >> ~/.bashrc
    echo '    echo " a:f  /     \\._____.d|    .'\''"' >> ~/.bashrc
    echo '    echo "      \`--..__)888888P\`._.'\''"' >> ~/.bashrc
    echo '    echo -e "\033[0m"' >> ~/.bashrc
    echo '    echo ""' >> ~/.bashrc
    echo "fi" >> ~/.bashrc
    echo "Welcome message added to .bashrc"
else
    echo "Welcome message already exists in .bashrc"
fi
'@
        
        # Convert to base64 to avoid quoting issues
        $scriptBytes = [System.Text.Encoding]::UTF8.GetBytes($bashScript)
        $base64Script = [System.Convert]::ToBase64String($scriptBytes)
        
        # Execute the script
        $result = & wsl.exe -d $DistroName --user $Username bash -c "echo '$base64Script' | base64 -d | bash"
        
        if ($LASTEXITCODE -eq 0) {
            Write-Log "Welcome message configured successfully" -Level "SUCCESS"
        }
        else {
            Write-Log "Warning: Could not add welcome message to shell profiles" -Level "WARN"
        }
    }
    catch {
        Write-Log "Error setting up welcome message: $_" -Level "WARN"
    }
}

function Set-WSLDefaultUser {
    <#
    .SYNOPSIS
        Set up the default user for a WSL distribution with automated user creation
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$DistroName,
        
        [Parameter(Mandatory = $true)]
        [string]$Username,
        
        [Parameter(Mandatory = $true)]
        [SecureString]$Password
    )
    
    Write-Log "Setting up default user '$Username' for distribution '$DistroName'" -Level "INFO"
    
    try {
        # Convert secure string to plain text for use in WSL commands
        $plainPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password))
        
        # Method 1: Try using ubuntu config command (Ubuntu distributions)
        if ($DistroName -like "*Ubuntu*" -or $DistroName -eq "Ubuntu") {
            Write-Log "Using Ubuntu configuration method..." -Level "INFO"
            
            # Create user configuration script with sudoers setup
            $ubuntuConfigScript = @"
#!/bin/bash
set -e

# Suppress interactive prompts
export DEBIAN_FRONTEND=noninteractive

echo "Creating user $Username..."
useradd -m -s /bin/bash $Username
echo "${Username}:${plainPassword}" | chpasswd
usermod -aG sudo $Username

# Configure passwordless sudo for essential commands to avoid interactive prompts
echo "$Username ALL=(ALL) NOPASSWD: /usr/bin/apt-get, /usr/bin/apt, /usr/bin/curl, /usr/bin/wget" > /etc/sudoers.d/$Username
chmod 440 /etc/sudoers.d/$Username

echo "User $Username created successfully"
"@
            
            # Execute as root to create user
            $configResult = $ubuntuConfigScript | & wsl.exe -d $DistroName --user root bash
            
            if ($LASTEXITCODE -eq 0) {
                Write-Log "User created successfully using Ubuntu method" -Level "SUCCESS"
            }
            else {
                Write-Log "Ubuntu method failed, trying generic method..." -Level "WARN"
                throw "Ubuntu method failed"
            }
        }
        else {
            # Method 2: Generic Debian-based method
            Write-Log "Using generic Debian configuration method..." -Level "INFO"
            throw "Using generic method"
        }
        
        # Set the user as default for the distribution
        Write-Log "Setting $Username as default user..." -Level "INFO"
        
        # Try multiple methods to set default user
        $setDefaultUser = $false
        
        # Method 1: Use wsl --set-default-user (Windows 11 and newer WSL)
        try {
            $setUserResult = & wsl.exe -d $DistroName --set-default-user $Username 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Log "Default user set using --set-default-user flag" -Level "SUCCESS"
                $setDefaultUser = $true
            }
        }
        catch {
            Write-Log "WSL --set-default-user not available" -Level "INFO"
        }
        
        # Method 2: Use distribution-specific config (Ubuntu)
        if (-not $setDefaultUser -and ($DistroName -like "*Ubuntu*" -or $DistroName -eq "Ubuntu")) {
            try {
                $ubuntuConfigPath = "$env:LOCALAPPDATA\Packages\CanonicalGroupLimited.UbuntuonWindows_79rhkp1fndgsc\LocalState"
                if (-not (Test-Path $ubuntuConfigPath)) {
                    # Try different Ubuntu package names
                    $ubuntuPackages = Get-ChildItem "$env:LOCALAPPDATA\Packages" | Where-Object { $_.Name -like "*Ubuntu*" } | Select-Object -First 1
                    if ($ubuntuPackages) {
                        $ubuntuConfigPath = Join-Path $ubuntuPackages.FullName "LocalState"
                    }
                }
                
                if (Test-Path $ubuntuConfigPath) {
                    & ubuntu.exe config --default-user $Username 2>$null
                    if ($LASTEXITCODE -eq 0) {
                        Write-Log "Default user set using ubuntu config command" -Level "SUCCESS"
                        $setDefaultUser = $true
                    }
                }
            }
            catch {
                Write-Log "Ubuntu config method not available" -Level "INFO"
            }
        }
        
        # Method 3: Create /etc/wsl.conf to set default user
        if (-not $setDefaultUser) {
            Write-Log "Using /etc/wsl.conf method to set default user..." -Level "INFO"
            
            $wslConfContent = @"
[user]
default=$Username
"@
            
            $createWslConf = $wslConfContent | & wsl.exe -d $DistroName --user root tee /etc/wsl.conf
            if ($LASTEXITCODE -eq 0) {
                Write-Log "Default user configured in /etc/wsl.conf" -Level "SUCCESS"
                $setDefaultUser = $true
            }
        }
        
        if (-not $setDefaultUser) {
            Write-Log "Warning: Could not set default user, but user was created successfully" -Level "WARN"
        }
        
        # Test the user setup
        Write-Log "Testing user setup..." -Level "INFO"
        $testUser = & wsl.exe -d $DistroName --user $Username whoami 2>$null
        if ($LASTEXITCODE -eq 0 -and $testUser.Trim() -eq $Username) {
            Write-Log "User setup verified successfully" -Level "SUCCESS"
            
            # Add welcome message to user's shell profile
            Write-Log "Setting up welcome message..." -Level "INFO"
            Set-WSLWelcomeMessage -DistroName $DistroName -Username $Username
            
            return $true
        }
        else {
            Write-Log "User verification failed" -Level "ERROR"
            return $false
        }
    }
    catch {
        Write-Log "Error setting up default user: $_" -Level "ERROR"
        
        # Fallback: Generic method for any Debian-based distribution
        try {
            Write-Log "Attempting fallback user creation method..." -Level "INFO"
            
            # Convert secure string to plain text
            $plainPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password))
            
            # Generic user creation script with sudoers configuration
            $genericScript = @"
#!/bin/bash
set -e

# Check if user already exists
if id "$Username" &>/dev/null; then
    echo "User $Username already exists"
else
    echo "Creating user $Username..."
    useradd -m -s /bin/bash $Username
    echo "${Username}:${plainPassword}" | chpasswd
    
    # Add to sudo group if it exists
    if getent group sudo &>/dev/null; then
        usermod -aG sudo $Username
    fi
    
    # Add to wheel group if it exists (some distributions)
    if getent group wheel &>/dev/null; then
        usermod -aG wheel $Username
    fi
    
    # Configure passwordless sudo for essential commands to avoid prompts
    echo "$Username ALL=(ALL) NOPASSWD: /usr/bin/apt-get, /usr/bin/apt, /usr/bin/curl, /usr/bin/wget" >> /etc/sudoers.d/$Username
    chmod 440 /etc/sudoers.d/$Username
fi

echo "User setup completed"
"@
            
            $fallbackResult = $genericScript | & wsl.exe -d $DistroName --user root bash
            
            if ($LASTEXITCODE -eq 0) {
                Write-Log "Fallback user creation succeeded" -Level "SUCCESS"
                
                # Try to set as default user
                $wslConfContent = @"
[user]
default=$Username
"@
                $wslConfContent | & wsl.exe -d $DistroName --user root tee /etc/wsl.conf > $null
                
                return $true
            }
            else {
                Write-Log "Fallback user creation failed" -Level "ERROR"
                return $false
            }
        }
        catch {
            Write-Log "Fallback method also failed: $_" -Level "ERROR"
            return $false
        }
    }
    finally {
        # Clear plain text password from memory
        if ($plainPassword) {
            $plainPassword = $null
            [System.GC]::Collect()
        }
    }
}

function Install-WSLDistributionAlternative {
    <#
    .SYNOPSIS
        Alternative method to install WSL distribution
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$DistroName
    )
    
    try {
        Write-Log "Using Microsoft Store method for distribution installation..." -Level "INFO"
        
        # For Ubuntu, we can try the direct store installation
        if ($DistroName -eq "Ubuntu" -or $DistroName -like "Ubuntu*") {
            $storeUrl = "ms-windows-store://pdp/?productid=9PDXGNCFSCZV"  # Ubuntu 22.04 LTS
            
            Write-Log "Opening Microsoft Store for Ubuntu installation..." -Level "INFO"
            Write-Log "Please install Ubuntu from the Microsoft Store and run this script again" -Level "INFO"
            
            Start-Process $storeUrl
            
            Write-Host "After installing Ubuntu from the Store, press any key to continue..." -ForegroundColor Yellow
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            
            # Check if installation was successful
            Start-Sleep -Seconds 2
            $checkDistros = & wsl.exe --list --quiet 2>$null
            if ($checkDistros -and ($checkDistros -contains $DistroName -or $checkDistros -like "*Ubuntu*")) {
                Write-Log "Distribution installation completed via Microsoft Store" -Level "SUCCESS"
                return $true
            }
            else {
                Write-Log "Distribution not found after Store installation. Please verify the installation." -Level "WARN"
                return $false
            }
        }
        else {
            Write-Log "For distribution '$DistroName', please install manually from Microsoft Store or use:" -Level "INFO"
            Write-Log "wsl --install -d $DistroName" -Level "INFO"
            return $false
        }
    }
    catch {
        Write-Log "Alternative installation method failed: $_" -Level "ERROR"
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
        [string]$DistroName,
        
        [Parameter(Mandatory = $true)]
        [string]$Username
    )
    
    Write-Log "Installing Starship and dependencies in WSL: $DistroName" -Level "INFO"
    
    $wslScript = @'
#!/bin/bash
set -e

# Suppress interactive prompts
export DEBIAN_FRONTEND=noninteractive

echo "Updating package lists..."
# Use sudo without password prompt (configured during user setup)
sudo -n apt-get update -qq 2>/dev/null || {
    echo "Error: sudo access not configured properly. Continuing without system updates."
}

echo "Installing dependencies..."
# Try to install with sudo, fallback if it fails
if sudo -n apt-get install -y curl unzip fonts-firacode 2>/dev/null; then
    echo "Dependencies installed successfully"
else
    echo "Warning: Could not install system packages. Continuing with Starship installation..."
fi

echo "Installing Starship prompt to user directory..."
# Create local bin directory if it doesn't exist
mkdir -p "$HOME/.local/bin"

# Download and install Starship to user's local bin
export BIN_DIR="$HOME/.local/bin"
curl -sS https://starship.rs/install.sh | sh -s -- -y -b "$BIN_DIR" 2>/dev/null

# Ensure local bin is in PATH
export PATH="$HOME/.local/bin:$PATH"

echo "Configuring shell integration..."
# Configure bash
BASHRC="$HOME/.bashrc"
# Add local bin to PATH if not already there
if ! grep -q '$HOME/.local/bin' "$BASHRC" 2>/dev/null; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$BASHRC"
fi

if ! grep -q "starship init" "$BASHRC" 2>/dev/null; then
    echo 'eval "$(starship init bash)"' >> "$BASHRC"
    echo "Added Starship to .bashrc"
fi

# Configure zsh if present
if [ -f "$HOME/.zshrc" ]; then
    # Add local bin to PATH if not already there
    if ! grep -q '$HOME/.local/bin' "$HOME/.zshrc" 2>/dev/null; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
    fi
    
    if ! grep -q "starship init" "$HOME/.zshrc" 2>/dev/null; then
        echo 'eval "$(starship init zsh)"' >> "$HOME/.zshrc"
        echo "Added Starship to .zshrc"
    fi
fi

echo "Starship installation completed successfully"
'@
    
    try {
        # Create script in WSL-accessible location using base64 encoding to avoid quoting issues
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
        
        # Execute the script within WSL with the configured user
        Write-Log "Executing Starship installation script..." -Level "INFO"
        $wslProcess = Start-Process -FilePath "wsl.exe" -ArgumentList "-d", $DistroName, "--user", $Username, "bash", $wslTempPath -Wait -PassThru -NoNewWindow
        
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
        Install FiraCode Nerd Font with modern approach and cleanup
    #>
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
        
        # Suppress progress bar and download quietly
        $ProgressPreference = 'SilentlyContinue'
        try {
            $webClient.DownloadFile($fontUrl, $zipPath)
        }
        finally {
            $webClient.Dispose()
            $ProgressPreference = 'Continue'
        }
        
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
                    # Try to use font validation if System.Drawing is available
                    $fontValid = $true
                    try {
                        if ([System.Type]::GetType("System.Drawing.Text.PrivateFontCollection")) {
                            $fontBytes = [System.IO.File]::ReadAllBytes($fontFile.FullName)
                            $fontCollection = New-Object System.Drawing.Text.PrivateFontCollection
                            $fontCollection.AddMemoryFont($fontBytes, $fontBytes.Length)
                            $fontCollection.Dispose()
                        }
                    }
                    catch {
                        Write-Log "Font validation skipped for $($fontFile.Name): $_" -Level "INFO"
                    }
                    
                    if ($fontValid) {
                        # Copy font to system fonts directory
                        Copy-Item -Path $fontFile.FullName -Destination $destinationPath -Force
                        
                        # Register font with Windows (for better compatibility)
                        try {
                            # Use Windows API to install font silently
                            $signature = @'
[DllImport("gdi32.dll", CharSet = CharSet.Auto)]
public static extern int AddFontResource(string lpszFilename);

[DllImport("user32.dll", CharSet = CharSet.Auto)]
public static extern int SendMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);
'@
                            $type = Add-Type -MemberDefinition $signature -Name FontInstaller -Namespace Win32Functions -PassThru -ErrorAction SilentlyContinue
                            
                            # Add font resource
                            $result = [Win32Functions.FontInstaller]::AddFontResource($destinationPath)
                            if ($result -gt 0) {
                                # Broadcast font change message
                                $HWND_BROADCAST = [IntPtr]0xffff
                                $WM_FONTCHANGE = 0x1D
                                [Win32Functions.FontInstaller]::SendMessage($HWND_BROADCAST, $WM_FONTCHANGE, [IntPtr]::Zero, [IntPtr]::Zero)
                                
                                # Register in registry for persistence
                                $regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
                                $fontName = [System.IO.Path]::GetFileNameWithoutExtension($fontFile.Name)
                                Set-ItemProperty -Path $regPath -Name "$fontName (TrueType)" -Value $fontFile.Name -ErrorAction SilentlyContinue
                            }
                        }
                        catch {
                            # Fallback: Just copy the file (already done above)
                            Write-Log "Used fallback font installation for $($fontFile.Name)" -Level "INFO"
                        }
                        
                        Write-Log "Installed font: $($fontFile.Name)" -Level "SUCCESS"
                        $installedCount++
                    }
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
        $settingsObj = $null
        if (Test-Path $settingsPath) {
            $settingsContent = Get-Content $settingsPath -Raw -Encoding UTF8
            if ($settingsContent.Trim()) {
                $settingsObj = $settingsContent | ConvertFrom-Json
            }
        }
        
        # Convert to hashtable for easier manipulation
        $settings = @{}
        if ($settingsObj) {
            # Convert PSCustomObject to hashtable
            $settingsObj.PSObject.Properties | ForEach-Object {
                $settings[$_.Name] = $_.Value
            }
        }
        
        # Update font settings
        $settings["terminal.integrated.fontFamily"] = "FiraCode Nerd Font"
        $settings["editor.fontFamily"] = "FiraCode Nerd Font, Consolas, 'Courier New', monospace"
        $settings["editor.fontLigatures"] = $true
        
        # Ensure directory exists
        $settingsDir = Split-Path $settingsPath -Parent
        if (-not (Test-Path $settingsDir)) {
            New-Item -Path $settingsDir -ItemType Directory -Force | Out-Null
        }
        
        # Write settings
        $settingsJson = $settings | ConvertTo-Json -Depth 20
        Set-Content -Path $settingsPath -Value $settingsJson -Encoding UTF8
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
        
        # Collect WSL user credentials for automated setup
        Write-Log "Collecting WSL user credentials..." -Level "INFO"
        $wslCredentials = Get-WSLCredentials -Username $WSLUsername -Password $WSLPassword
        
        # Validate prerequisites
        Test-Prerequisites
        
        # Step 1: Install WSL Distribution
        Write-Log "=== Step 1: WSL Distribution Setup ===" -Level "INFO"
        $wslResult = Install-WSLDistribution -DistroName $DistroName -Username $wslCredentials.Username -Password $wslCredentials.Password
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
            $starshipResult = Install-StarshipInWSL -DistroName $DistroName -Username $wslCredentials.Username
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
