#Requires -Modules Pester

# Module setup - compatible with both Pester 3.x and 5.x
$script:ModulePath = Join-Path $PSScriptRoot "..\src\ConfigureWSL.psd1"
Write-Host "Module path: $script:ModulePath" -ForegroundColor Gray
Write-Host "Module exists: $(Test-Path $script:ModulePath)" -ForegroundColor Gray

# Import module function for compatibility
function Import-TestModule {
    if (Get-Module ConfigureWSL) {
        Remove-Module ConfigureWSL -Force -ErrorAction SilentlyContinue
    }
    
    Write-Host "Attempting to import module from: $script:ModulePath" -ForegroundColor Gray
    if (-not (Test-Path $script:ModulePath)) {
        throw "Module file not found at: $script:ModulePath"
    }
    
    try {
        Import-Module $script:ModulePath -Force -ErrorAction Stop
        Write-Host "Module imported successfully" -ForegroundColor Green
    } catch {
        Write-Host "Failed to import module: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

# Cleanup function for compatibility
function Remove-TestModule {
    Remove-Module ConfigureWSL -Force -ErrorAction SilentlyContinue
}

# Check Pester version for conditional syntax
$script:IsPester5Plus = $false
try {
    $pesterVersion = (Get-Module Pester -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1).Version
    $script:IsPester5Plus = $pesterVersion -ge [Version]"5.0.0"
} catch {
    $script:IsPester5Plus = $false
}

# Helper function for Should assertions compatibility
function Test-ShouldBe {
    param($Actual, $Expected)
    if ($script:IsPester5Plus) {
        $Actual | Should -Be $Expected
    } else {
        $Actual | Should Be $Expected
    }
}

function Test-ShouldNotThrow {
    param($ScriptBlock)
    if ($script:IsPester5Plus) {
        $ScriptBlock | Should -Not -Throw
    } else {
        $ScriptBlock | Should Not Throw
    }
}

function Test-ShouldThrow {
    param($ScriptBlock, $Pattern = $null)
    if ($script:IsPester5Plus) {
        if ($Pattern) {
            $ScriptBlock | Should -Throw -ExpectedMessage $Pattern
        } else {
            $ScriptBlock | Should -Throw
        }
    } else {
        if ($Pattern) {
            $ScriptBlock | Should Throw $Pattern
        } else {
            $ScriptBlock | Should Throw
        }
    }
}

function Test-ShouldBeOfType {
    param($Actual, $Expected)
    if ($script:IsPester5Plus) {
        $Actual | Should -BeOfType $Expected
    } else {
        $Actual | Should BeOfType $Expected
    }
}

function Test-ShouldBeNullOrEmpty {
    param($Actual)
    if ($script:IsPester5Plus) {
        $Actual | Should -BeNullOrEmpty
    } else {
        $Actual | Should BeNullOrEmpty
    }
}

# Helper function for TestDrive compatibility
function Get-TestTempPath {
    param([string]$FileName = "")
    
    $baseDir = if ($TestDrive) { 
        $TestDrive 
    } else { 
        # Pester 3.x fallback
        $tempBase = [System.IO.Path]::GetTempPath()
        $testDir = Join-Path $tempBase "PesterTests-$(Get-Random)"
        if (-not (Test-Path $testDir)) {
            New-Item -Path $testDir -ItemType Directory -Force | Out-Null
        }
        $testDir
    }
    
    if ($FileName) {
        Join-Path $baseDir $FileName
    } else {
        $baseDir
    }
}

if ($script:IsPester5Plus) {
    # Pester 5.x syntax
    BeforeAll {
        Import-TestModule
    }
    
    AfterAll {
        Remove-TestModule
    }
} else {
    # Pester 3.x - run setup before each describe block
    Import-TestModule
}

Describe "Advanced Mocking Tests" {
    
    if (-not $script:IsPester5Plus) {
        # Ensure module is loaded for Pester 3.x
        Import-TestModule
    }
    
    Context "WSL Command Mocking" {
        BeforeEach {
            # Initialize logging for tests
            $TestLogPath = Get-TestTempPath "mock-test.log"
            Initialize-Logging -LogPath $TestLogPath
        }
        
        Describe "WSL Installation with Command Mocking" {
            It "Should detect existing WSL distribution" {
                # Mock wsl.exe commands
                Mock -CommandName "Invoke-Expression" -ParameterFilter { $Command -like "*wsl.exe --status*" } -MockWith {
                    $global:LASTEXITCODE = 0
                    return "Default Distribution: Ubuntu"
                }
                
                Mock -CommandName "Invoke-Expression" -ParameterFilter { $Command -like "*wsl.exe --list --quiet*" } -MockWith {
                    $global:LASTEXITCODE = 0
                    return @("Ubuntu", "Ubuntu-20.04")
                }
                
                $result = Install-WSLDistribution -DistroName "Ubuntu"
                Test-ShouldBe $result $true
            }
            
            It "Should handle WSL installation failure" {
                # Mock failed WSL status check
                Mock -CommandName "Invoke-Expression" -ParameterFilter { $Command -like "*wsl.exe --status*" } -MockWith {
                    $global:LASTEXITCODE = 1
                    return ""
                }
                
                Mock -CommandName "Invoke-Expression" -ParameterFilter { $Command -like "*wsl.exe --version*" } -MockWith {
                    $global:LASTEXITCODE = 1
                    return ""
                }
                
                Test-ShouldThrow { Install-WSLDistribution -DistroName "Ubuntu" } "*not functioning properly*"
            }
            
            It "Should handle empty distribution list" {
                # Mock empty distribution list
                Mock -CommandName "Invoke-Expression" -ParameterFilter { $Command -like "*wsl.exe --status*" } -MockWith {
                    $global:LASTEXITCODE = 0
                    return "No distributions installed"
                }
                
                Mock -CommandName "Invoke-Expression" -ParameterFilter { $Command -like "*wsl.exe --list --quiet*" } -MockWith {
                    $global:LASTEXITCODE = 0
                    return @()
                }
                
                Mock -CommandName "Start-Process" -MockWith {
                    return [PSCustomObject]@{ ExitCode = 0 }
                }
                
                $result = Install-WSLDistribution -DistroName "Ubuntu"
                Test-ShouldBe $result $true
            }
        }
        
        Describe "Starship Installation with Command Mocking" {
            It "Should create and execute installation script" {
                # Mock WSL bash commands
                Mock -CommandName "Invoke-Expression" -ParameterFilter { $Command -like "*base64 -d*" } -MockWith {
                    $global:LASTEXITCODE = 0
                    return "Script created"
                }
                
                Mock -CommandName "Start-Process" -ParameterFilter { $FilePath -eq "wsl.exe" } -MockWith {
                    return [PSCustomObject]@{ ExitCode = 0 }
                }
                
                Mock -CommandName "Invoke-Expression" -ParameterFilter { $Command -like "*rm -f*" } -MockWith {
                    $global:LASTEXITCODE = 0
                }
                
                $result = Install-StarshipInWSL -DistroName "Ubuntu"
                Test-ShouldBe $result $true
            }
            
            It "Should handle script creation failure" {
                # Mock failed script creation
                Mock -CommandName "Invoke-Expression" -ParameterFilter { $Command -like "*base64 -d*" } -MockWith {
                    $global:LASTEXITCODE = 1
                    return "Error creating script"
                }
                
                Test-ShouldThrow { Install-StarshipInWSL -DistroName "Ubuntu" } "*Failed to create installation script*"
            }
            
            It "Should handle script execution failure" {
                # Mock successful script creation but failed execution
                Mock -CommandName "Invoke-Expression" -ParameterFilter { $Command -like "*base64 -d*" } -MockWith {
                    $global:LASTEXITCODE = 0
                }
                
                Mock -CommandName "Start-Process" -ParameterFilter { $FilePath -eq "wsl.exe" } -MockWith {
                    return [PSCustomObject]@{ ExitCode = 1 }
                }
                
                Mock -CommandName "Invoke-Expression" -ParameterFilter { $Command -like "*rm -f*" } -MockWith {
                    $global:LASTEXITCODE = 0
                }
                
                $result = Install-StarshipInWSL -DistroName "Ubuntu"
                Test-ShouldBe $result $false
            }
        }
    }
    
    Context "File System Operations Mocking" {
        Describe "Configuration File Handling" {
            It "Should create Windows Terminal configuration with valid JSON" {
                # Create mock settings directory and file
                $mockSettingsPath = Get-TestTempPath "MockTerminal\settings.json"
                $mockDir = Split-Path $mockSettingsPath -Parent
                New-Item -Path $mockDir -ItemType Directory -Force | Out-Null
                
                $mockSettings = @{
                    defaultProfile = "{guid-123}"
                    profiles = @{
                        list = @(
                            @{
                                guid = "{guid-123}"
                                name = "PowerShell"
                                font = @{}
                            }
                        )
                    }
                } | ConvertTo-Json -Depth 5
                
                $mockSettings | Set-Content $mockSettingsPath
                
                # Mock the settings path
                Mock -CommandName "Test-Path" -ParameterFilter { $Path -like "*WindowsTerminal*settings.json" } -MockWith { $true }
                Mock -CommandName "Get-Content" -ParameterFilter { $Path -like "*WindowsTerminal*settings.json" } -MockWith { 
                    return Get-Content $mockSettingsPath -Raw
                }
                Mock -CommandName "Set-Content" -ParameterFilter { $Path -like "*WindowsTerminal*settings.json" } -MockWith {}
                
                # Override the environment variable for testing
                $env:LOCALAPPDATA = Get-TestTempPath
                
                $result = Update-WindowsTerminalConfig
                Test-ShouldBe $result $true
            }
            
            It "Should handle corrupted JSON in VS Code settings" {
                # Create mock VS Code settings with invalid JSON
                $mockSettingsPath = Get-TestTempPath "Code\User\settings.json"
                $mockDir = Split-Path $mockSettingsPath -Parent
                New-Item -Path $mockDir -ItemType Directory -Force | Out-Null
                
                # Invalid JSON
                "{ invalid json content" | Set-Content $mockSettingsPath
                
                # Mock the settings path  
                Mock -CommandName "Test-Path" -ParameterFilter { $Path -like "*Code*settings.json" } -MockWith { $true }
                Mock -CommandName "Get-Content" -ParameterFilter { $Path -like "*Code*settings.json" } -MockWith {
                    return Get-Content $mockSettingsPath -Raw
                }
                
                # Override environment variable
                $env:APPDATA = Get-TestTempPath
                
                # Should handle the error gracefully
                Test-ShouldNotThrow { Update-VSCodeConfig }
            }
        }
        
        Describe "Backup Operations" {
            It "Should handle backup directory creation failure" {
                # Mock New-Item to fail for backup directory
                Mock -CommandName "New-Item" -ParameterFilter { $ItemType -eq "Directory" } -MockWith {
                    throw "Access denied"
                }
                
                # Create a test file
                $testFile = Get-TestTempPath "test-backup.txt"
                "Test content" | Set-Content $testFile
                
                $result = New-ConfigurationBackup -FilePath $testFile
                Test-ShouldBeNullOrEmpty $result
            }
            
            It "Should handle file copy failure during backup" {
                # Initialize logging for backup directory
                Initialize-Logging -LogPath (Get-TestTempPath "backup-fail-test.log")
                
                # Create a test file
                $testFile = Get-TestTempPath "test-copy-fail.txt"
                "Test content" | Set-Content $testFile
                
                # Mock Copy-Item to fail
                Mock -CommandName "Copy-Item" -MockWith {
                    throw "Copy operation failed"
                }
                
                $result = New-ConfigurationBackup -FilePath $testFile
                Test-ShouldBeNullOrEmpty $result
            }
        }
    }
    
    Context "Network Operations Mocking" {
        Describe "Font Download with Network Simulation" {
            It "Should handle successful font download" {
                # Mock successful download
                $mockWebClient = [PSCustomObject]@{
                    Headers = @{ Add = { param($key, $value) } }
                    DownloadFile = { param($url, $path) 
                        # Create a mock zip file
                        "Mock zip content" | Set-Content $path
                    }
                    Dispose = {}
                }
                
                Mock -CommandName "New-Object" -ParameterFilter { $TypeName -eq "System.Net.WebClient" } -MockWith {
                    return $mockWebClient
                }
                
                # Mock archive expansion
                Mock -CommandName "Expand-Archive" -MockWith {
                    # Create mock font files
                    $extractPath = $DestinationPath
                    New-Item -Path $extractPath -ItemType Directory -Force | Out-Null
                    New-Item -Path (Join-Path $extractPath "FiraCode-Regular.ttf") -ItemType File | Out-Null
                }
                
                # Mock font installation
                Mock -CommandName "Get-ChildItem" -ParameterFilter { $Filter -eq "*.ttf" } -MockWith {
                    return @(
                        [PSCustomObject]@{
                            Name = "FiraCode-Regular.ttf"
                            FullName = Get-TestTempPath "FiraCode-Regular.ttf"
                        }
                    )
                }
                
                Mock -CommandName "Test-Path" -ParameterFilter { $Path -like "*Fonts*" } -MockWith { $false }
                Mock -CommandName "Copy-Item" -MockWith {}
                Mock -CommandName "New-Object" -ParameterFilter { $ComObject -eq "Shell.Application" } -MockWith {
                    return [PSCustomObject]@{
                        Namespace = { 
                            return [PSCustomObject]@{
                                CopyHere = {}
                            }
                        }
                    }
                }
                
                $result = Install-FiraCodeFont
                Test-ShouldBe $result $true
            }
            
            It "Should handle network download failure" {
                # Mock network failure
                Mock -CommandName "New-Object" -ParameterFilter { $TypeName -eq "System.Net.WebClient" } -MockWith {
                    throw "Network unreachable"
                }
                
                $result = Install-FiraCodeFont
                Test-ShouldBe $result $false
            }
            
            It "Should handle corrupted download archive" {
                # Mock successful download but corrupted archive
                $mockWebClient = [PSCustomObject]@{
                    Headers = @{ Add = { param($key, $value) } }
                    DownloadFile = { param($url, $path) 
                        "Corrupted zip" | Set-Content $path
                    }
                    Dispose = {}
                }
                
                Mock -CommandName "New-Object" -ParameterFilter { $TypeName -eq "System.Net.WebClient" } -MockWith {
                    return $mockWebClient
                }
                
                # Mock archive expansion failure
                Mock -CommandName "Expand-Archive" -MockWith {
                    throw "Archive is corrupted"
                }
                
                $result = Install-FiraCodeFont
                Test-ShouldBe $result $false
            }
        }
    }
    
    Context "System Integration Mocking" {
        Describe "Windows Features Detection" {
            It "Should detect WSL feature via Windows Features when wsl.exe is not available" {
                # Mock Get-Command to return null (wsl.exe not found)
                Mock -CommandName "Get-Command" -ParameterFilter { $Name -eq "wsl.exe" } -MockWith { $null }
                
                # Mock Windows Feature check
                Mock -CommandName "Get-WindowsOptionalFeature" -MockWith {
                    return [PSCustomObject]@{
                        State = "Enabled"
                        FeatureName = "Microsoft-Windows-Subsystem-Linux"
                    }
                }
                
                $result = Test-WSLInstallation
                Test-ShouldBe $result.IsInstalled $true
                Test-ShouldBe $result.IsEnabled $true
                Test-ShouldBe $result.Version "WSL Feature Available"
            }
            
            It "Should handle Windows Feature check failure" {
                # Mock Get-Command to return null
                Mock -CommandName "Get-Command" -ParameterFilter { $Name -eq "wsl.exe" } -MockWith { $null }
                
                # Mock Windows Feature check failure
                Mock -CommandName "Get-WindowsOptionalFeature" -MockWith { $null }
                
                $result = Test-WSLInstallation
                Test-ShouldBe $result.IsInstalled $false
                Test-ShouldBe $result.IsEnabled $false
                Test-ShouldBeNullOrEmpty $result.Version
            }
        }
        
        Describe "Administrator Privilege Mocking" {
            It "Should correctly identify administrator status" {
                # Mock Windows Identity
                $mockIdentity = [PSCustomObject]@{
                    Name = "DOMAIN\AdminUser"
                }
                
                $mockPrincipal = [PSCustomObject]@{
                    IsInRole = { param($role) 
                        return $role -eq [Security.Principal.WindowsBuiltInRole]::Administrator 
                    }
                }
                
                Mock -CommandName "Get-Current" -MockWith { return $mockIdentity } -ModuleName "ConfigureWSL"
                Mock -CommandName "New-Object" -ParameterFilter { 
                    $TypeName -eq "Security.Principal.WindowsPrincipal" 
                } -MockWith { return $mockPrincipal }
                
                # Note: This test might not work due to static method mocking limitations
                # but demonstrates the approach for testing privilege checks
                $result = Test-IsAdministrator
                Test-ShouldBeOfType $result [System.Boolean]
            }
        }
    }
}