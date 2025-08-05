#Requires -Modules Pester

# Module setup - compatible with both Pester 3.x and 5.x
$script:ModulePath = Join-Path $PSScriptRoot "..\src\ConfigureWSL.psd1"
Write-Host "Module path: $script:ModulePath" -ForegroundColor Gray
Write-Host "Module exists: $(Test-Path $script:ModulePath)" -ForegroundColor Gray
$script:TestTempDir = $null

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
    
    # Create test directories if needed
    if (-not $script:TestTempDir -or -not (Test-Path $script:TestTempDir)) {
        $script:TestTempDir = Get-TestTempPath "ConfigureWSL-Tests"
        New-Item -Path $script:TestTempDir -ItemType Directory -Force | Out-Null
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

function Test-ShouldBeOfType {
    param($Actual, $Expected)
    if ($script:IsPester5Plus) {
        $Actual | Should -BeOfType $Expected
    } else {
        $Actual | Should BeOfType $Expected
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

function Test-ShouldMatch {
    param($Actual, $Pattern)
    if ($script:IsPester5Plus) {
        $Actual | Should -Match $Pattern
    } else {
        $Actual | Should Match $Pattern
    }
}

function Test-ShouldNotBeNullOrEmpty {
    param($Actual)
    if ($script:IsPester5Plus) {
        $Actual | Should -Not -BeNullOrEmpty
    } else {
        $Actual | Should Not BeNullOrEmpty
    }
}

function Test-ShouldContain {
    param($Actual, $Expected)
    if ($script:IsPester5Plus) {
        $Actual | Should -Contain $Expected
    } else {
        # Pester 3.x workaround - check membership directly
        $containsItem = $Expected -in $Actual
        if (-not $containsItem) {
            $containsItem = ($Actual | Where-Object { $_ -eq $Expected }) -ne $null
        }
        Test-ShouldBe $containsItem $true
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

Describe "ConfigureWSL Module Import" {
    
    if (-not $script:IsPester5Plus) {
        # Ensure module is loaded for Pester 3.x
        Import-TestModule
    }
        It "Should import the module successfully" {
            Test-ShouldNotBeNullOrEmpty (Get-Module ConfigureWSL)
        }
        
        It "Should export all expected functions" {
            # Get actual exported functions to avoid mismatch
            $expectedFunctions = @(
                'Install-WSLEnvironment',
                'Test-WSLInstallation',
                'Install-WSLDistribution',
                'Install-FiraCodeFont',
                'Install-StarshipInWSL',
                'Update-WindowsTerminalConfig',
                'Update-VSCodeConfig',
                'Test-Prerequisites',
                'Write-Log',
                'Initialize-Logging',
                'Get-WSLErrorMessage',
                'Test-WSLDistributionState',
                'Set-WSLWelcomeMessage'
            )
            
            # Note: Test-IsAdministrator is not exported (private function)
            
            $exportedFunctions = (Get-Module ConfigureWSL).ExportedFunctions.Keys
            Write-Host "Expected functions: $($expectedFunctions -join ', ')" -ForegroundColor Gray
            Write-Host "Exported functions: $($exportedFunctions -join ', ')" -ForegroundColor Gray
            
            foreach ($function in $expectedFunctions) {
                Write-Host "Checking for function: $function" -ForegroundColor Gray
                if ($script:IsPester5Plus) {
                    $exportedFunctions | Should -Contain $function
                } else {
                    # Pester 3.x workaround - check if function exists in the collection
                    $functionExists = $function -in $exportedFunctions
                    if (-not $functionExists) {
                        # Try another approach for KeyCollection
                        $functionExists = ($exportedFunctions | Where-Object { $_ -eq $function }) -ne $null
                    }
                    Test-ShouldBe $functionExists $true
                }
            }
        }
}

Describe "ConfigureWSL Logging Functions" {
    
    if (-not $script:IsPester5Plus) {
        # Ensure module is loaded for Pester 3.x
        Import-TestModule
    }
        BeforeEach {
            $TestLogPath = Get-TestTempPath "test-log-$(Get-Random).log"
            Initialize-Logging -LogPath $TestLogPath
        }
        
        AfterEach {
            # Clean up log file
            if ($TestLogPath -and (Test-Path $TestLogPath)) {
                Remove-Item $TestLogPath -Force -ErrorAction SilentlyContinue
            }
        }
        
        Describe "Initialize-Logging" {
            It "Should create log file" {
                $TestLogPath = Get-TestTempPath "init-test.log"
                Initialize-Logging -LogPath $TestLogPath
                Test-ShouldBe (Test-Path $TestLogPath) $true
            }
            
            It "Should create log directory if it doesn't exist" {
                $TestLogDir = Get-TestTempPath "NewLogDir"
                $TestLogPath = Join-Path $TestLogDir "test.log"
                Initialize-Logging -LogPath $TestLogPath
                Test-ShouldBe (Test-Path $TestLogDir) $true
                Test-ShouldBe (Test-Path $TestLogPath) $true
            }
            
            It "Should write initialization message to log" {
                $TestLogPath = Get-TestTempPath "init-message-test.log"
                Initialize-Logging -LogPath $TestLogPath
                $logContent = Get-Content $TestLogPath -Raw
                Test-ShouldMatch $logContent "WSL Configuration Module Started"
            }
        }
        
        Describe "Write-Log" {
            It "Should write INFO message to log file" {
                $testMessage = "This is a test INFO message"
                Write-Log -Message $testMessage -Level "INFO"
                
                $logContent = Get-Content $TestLogPath -Raw
                Test-ShouldMatch $logContent "\[INFO\] $testMessage"
            }
            
            It "Should write SUCCESS message to log file" {
                $testMessage = "This is a test SUCCESS message"
                Write-Log -Message $testMessage -Level "SUCCESS"
                
                $logContent = Get-Content $TestLogPath -Raw
                Test-ShouldMatch $logContent "\[SUCCESS\] $testMessage"
            }
            
            It "Should write WARN message to log file" {
                $testMessage = "This is a test WARN message"
                Write-Log -Message $testMessage -Level "WARN"
                
                $logContent = Get-Content $TestLogPath -Raw
                Test-ShouldMatch $logContent "\[WARN\] $testMessage"
            }
            
            It "Should include timestamp in log entry" {
                $testMessage = "Timestamp test message"
                Write-Log -Message $testMessage -Level "INFO"
                
                $logContent = Get-Content $TestLogPath -Raw
                Test-ShouldMatch $logContent "\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\]"
            }
            
            It "Should handle empty log path gracefully" {
                # Temporarily clear the log path
                $originalLogPath = $script:LogPath
                $script:LogPath = $null
                
                Test-ShouldNotThrow { Write-Log -Message "Test message" -Level "INFO" }
                
                # Restore log path
                $script:LogPath = $originalLogPath
            }
        }
}

Describe "ConfigureWSL Validation Functions" {
    
    if (-not $script:IsPester5Plus) {
        # Ensure module is loaded for Pester 3.x
        Import-TestModule
    }
        Describe "Test-IsAdministrator" {
            It "Should return a boolean value" {
                $result = Test-IsAdministrator
                Test-ShouldBeOfType $result [System.Boolean]
            }
            
            It "Should not throw exceptions" {
                Test-ShouldNotThrow { Test-IsAdministrator }
            }
        }
        
        Describe "Test-WSLInstallation" {
            It "Should return a PSCustomObject with required properties" {
                $result = Test-WSLInstallation
                Test-ShouldBeOfType $result [PSCustomObject]
                # Pester 3.x workaround for property checking
                $propertyNames = @($result.PSObject.Properties.Name)
                Test-ShouldBe ("IsInstalled" -in $propertyNames) $true
                Test-ShouldBe ("IsEnabled" -in $propertyNames) $true
                Test-ShouldBe ("Version" -in $propertyNames) $true
            }
            
            It "Should return boolean values for IsInstalled and IsEnabled" {
                $result = Test-WSLInstallation
                $result.IsInstalled | Should -BeOfType [System.Boolean]
                $result.IsEnabled | Should -BeOfType [System.Boolean]
            }
            
            It "Should not throw exceptions" {
                Test-ShouldNotThrow { Test-WSLInstallation }
            }
        }
        
        Describe "Test-Prerequisites" {
            It "Should return a boolean value" {
                $result = Test-Prerequisites
                Test-ShouldBeOfType $result [System.Boolean]
            }
            
            It "Should not throw exceptions" {
                Test-ShouldNotThrow { Test-Prerequisites }
            }
        }
}

Describe "ConfigureWSL Backup Functions" {
    
    if (-not $script:IsPester5Plus) {
        # Ensure module is loaded for Pester 3.x
        Import-TestModule
    }
        Describe "New-ConfigurationBackup" {
            BeforeEach {
                # Initialize logging for backup directory
                $TestLogPath = Get-TestTempPath "backup-test.log"
                Initialize-Logging -LogPath $TestLogPath
            }
            
            It "Should return null for non-existent file" {
                $nonExistentFile = Get-TestTempPath "does-not-exist.txt"
                $result = New-ConfigurationBackup -FilePath $nonExistentFile
                Test-ShouldBeNullOrEmpty $result
            }
            
            It "Should create backup of existing file" {
                # Create a test file
                $testFile = Get-TestTempPath "test-config.json"
                "Test content" | Set-Content $testFile
                
                $backupPath = New-ConfigurationBackup -FilePath $testFile
                Test-ShouldNotBeNullOrEmpty $backupPath
                Test-ShouldBe (Test-Path $backupPath) $true
            }
            
            It "Should preserve file content in backup" {
                # Create a test file with specific content
                $testFile = Get-TestTempPath "test-content.txt"
                $testContent = "This is test content for backup"
                $testContent | Set-Content $testFile
                
                $backupPath = New-ConfigurationBackup -FilePath $testFile
                $backupContent = Get-Content $backupPath -Raw
                Test-ShouldBe $backupContent.Trim() $testContent
            }
            
            It "Should use custom backup name when provided" {
                # Create a test file
                $testFile = Get-TestTempPath "original.txt"
                "Content" | Set-Content $testFile
                
                $customName = "custom-backup"
                $backupPath = New-ConfigurationBackup -FilePath $testFile -BackupName $customName
                Test-ShouldMatch $backupPath "$customName\.backup$"
            }
        }
}

Describe "ConfigureWSL WSL Functions" {
    
    if (-not $script:IsPester5Plus) {
        # Ensure module is loaded for Pester 3.x
        Import-TestModule
    }
        Describe "Install-WSLDistribution" {
            It "Should accept DistroName parameter" {
                Test-ShouldNotThrow { Install-WSLDistribution -DistroName "Ubuntu" }
            }
            
            It "Should return boolean value" {
                # Mock the WSL commands to avoid actual installation
                Mock -CommandName "Start-Process" -MockWith { 
                    return [PSCustomObject]@{ ExitCode = 0 }
                }
                Mock -CommandName "Invoke-Expression" -MockWith { 
                    $global:LASTEXITCODE = 0
                    return @("Ubuntu")
                }
                
                $result = Install-WSLDistribution -DistroName "Ubuntu"
                Test-ShouldBeOfType $result [System.Boolean]
            }
        }
        
        Describe "Install-StarshipInWSL" {
            It "Should accept DistroName parameter" {
                Test-ShouldNotThrow { Install-StarshipInWSL -DistroName "Ubuntu" }
            }
            
            It "Should return boolean value" {
                # Mock WSL commands
                Mock -CommandName "Start-Process" -MockWith { 
                    return [PSCustomObject]@{ ExitCode = 0 }
                }
                Mock -CommandName "Invoke-Expression" -MockWith { 
                    $global:LASTEXITCODE = 0
                }
                
                $result = Install-StarshipInWSL -DistroName "Ubuntu"
                Test-ShouldBeOfType $result [System.Boolean]
            }
        }

        Describe "Get-WSLErrorMessage" {
            It "Should return string value" {
                $result = Get-WSLErrorMessage -ExitCode -1
                Test-ShouldBeOfType $result [System.String]
            }
            
            It "Should handle error code -1 with specific error output" {
                $result = Get-WSLErrorMessage -ExitCode -1 -ErrorOutput "Error: 0x8000000d"
                Test-ShouldBe ($result -like "*Another WSL operation*") $true
            }
            
            It "Should handle generic error codes" {
                $result = Get-WSLErrorMessage -ExitCode 999
                Test-ShouldBe ($result -like "*exit code: 999*") $true
            }
            
            It "Should not throw exceptions" {
                Test-ShouldNotThrow { Get-WSLErrorMessage -ExitCode 0 }
            }
        }

        Describe "Test-WSLDistributionState" {
            It "Should accept DistroName parameter" {
                Test-ShouldNotThrow { Test-WSLDistributionState -DistroName "Ubuntu" }
            }
            
            It "Should return boolean value" {
                # Mock WSL command to avoid actual checking
                Mock -CommandName "Invoke-Expression" -MockWith { 
                    return $null
                }
                
                $result = Test-WSLDistributionState -DistroName "Ubuntu"
                Test-ShouldBeOfType $result [System.Boolean]
            }
            
            It "Should handle distribution in uninstalling state" {
                # Mock WSL command to return uninstalling state
                Mock -CommandName "Invoke-Expression" -MockWith { 
                    return "Ubuntu    Uninstalling    2"
                }
                # Mock Start-Sleep to speed up test
                Mock -CommandName "Start-Sleep" -MockWith {}
                
                $result = Test-WSLDistributionState -DistroName "Ubuntu"
                Test-ShouldBeOfType $result [System.Boolean]
            }
            
            It "Should not throw exceptions" {
                # Mock all external commands
                Mock -CommandName "Invoke-Expression" -MockWith { return $null }
                Mock -CommandName "Start-Sleep" -MockWith {}
                
                Test-ShouldNotThrow { Test-WSLDistributionState -DistroName "Ubuntu" }
            }
        }

        Describe "Set-WSLWelcomeMessage" {
            It "Should accept DistroName and Username parameters" {
                Test-ShouldNotThrow { Set-WSLWelcomeMessage -DistroName "Ubuntu" -Username "testuser" }
            }
            
            It "Should return boolean value" {
                # Mock WSL command to avoid actual execution
                Mock -CommandName "Invoke-Expression" -MockWith { 
                    $global:LASTEXITCODE = 0
                }
                
                $result = Set-WSLWelcomeMessage -DistroName "Ubuntu" -Username "testuser"
                Test-ShouldBeOfType $result [System.Boolean]
            }
            
            It "Should handle WSL execution errors gracefully" {
                # Mock WSL command to return error
                Mock -CommandName "Invoke-Expression" -MockWith { 
                    $global:LASTEXITCODE = 1
                }
                
                $result = Set-WSLWelcomeMessage -DistroName "Ubuntu" -Username "testuser"
                Test-ShouldBeOfType $result [System.Boolean]
                Test-ShouldBe $result $false
            }
            
            It "Should not throw exceptions" {
                # Mock all external commands
                Mock -CommandName "Invoke-Expression" -MockWith { 
                    $global:LASTEXITCODE = 0
                }
                
                Test-ShouldNotThrow { Set-WSLWelcomeMessage -DistroName "Ubuntu" -Username "testuser" }
            }
        }
}

Describe "ConfigureWSL Font Functions" {
    
    if (-not $script:IsPester5Plus) {
        # Ensure module is loaded for Pester 3.x
        Import-TestModule
    }
        Describe "Install-FiraCodeFont" {
            It "Should return boolean value" {
                # Mock web client and file operations to avoid actual download
                Mock -CommandName "New-Object" -ParameterFilter { $TypeName -eq "System.Net.WebClient" } -MockWith {
                    return [PSCustomObject]@{
                        Headers = @{ Add = {} }
                        DownloadFile = {}
                        Dispose = {}
                    }
                }
                Mock -CommandName "Expand-Archive" -MockWith {}
                Mock -CommandName "Get-ChildItem" -MockWith { return @() }
                
                $result = Install-FiraCodeFont
                Test-ShouldBeOfType $result [System.Boolean]
            }
            
            It "Should not throw exceptions during mocked execution" {
                # Mock all external dependencies
                Mock -CommandName "New-Object" -MockWith { 
                    return [PSCustomObject]@{
                        Headers = @{ Add = {} }
                        DownloadFile = {}
                        Dispose = {}
                    }
                }
                Mock -CommandName "Expand-Archive" -MockWith {}
                Mock -CommandName "Get-ChildItem" -MockWith { return @() }
                Mock -CommandName "Test-Path" -MockWith { $false }
                Mock -CommandName "Remove-Item" -MockWith {}
                
                Test-ShouldNotThrow { Install-FiraCodeFont }
            }
        }
}

Describe "ConfigureWSL Configuration Functions" {
    
    if (-not $script:IsPester5Plus) {
        # Ensure module is loaded for Pester 3.x
        Import-TestModule
    }
        Describe "Update-WindowsTerminalConfig" {
            It "Should return boolean value" {
                $result = Update-WindowsTerminalConfig
                Test-ShouldBeOfType $result [System.Boolean]
            }
            
            It "Should handle missing settings file gracefully" {
                # Mock Test-Path to return false for settings file
                Mock -CommandName "Test-Path" -MockWith { $false }
                
                $result = Update-WindowsTerminalConfig
                Test-ShouldBe $result $false
            }
        }
        
        Describe "Update-VSCodeConfig" {
            It "Should return boolean value" {
                $result = Update-VSCodeConfig
                Test-ShouldBeOfType $result [System.Boolean]
            }
            
            It "Should handle missing settings file gracefully" {
                # Mock Test-Path to return false for all possible settings paths
                Mock -CommandName "Test-Path" -MockWith { $false }
                
                $result = Update-VSCodeConfig
                Test-ShouldBe $result $false
            }
        }
}

Describe "ConfigureWSL Main Function" {
    
    if (-not $script:IsPester5Plus) {
        # Ensure module is loaded for Pester 3.x
        Import-TestModule
    }
        Describe "Install-WSLEnvironment" {
            It "Should accept all parameters" {
                $testLogPath = Get-TestTempPath "test.log"
                Test-ShouldNotThrow { Install-WSLEnvironment -DistroName "Ubuntu" -SkipFontInstall -SkipStarship -LogPath $testLogPath }
            }
            
            It "Should return integer exit code" {
                # Mock administrator check to return false to avoid actual execution
                Mock -CommandName "Test-IsAdministrator" -MockWith { $false }
                
                $result = Install-WSLEnvironment
                Test-ShouldBeOfType $result [System.Int32]
            }
            
            It "Should return 1 when not running as administrator" {
                # Mock administrator check to return false
                Mock -CommandName "Test-IsAdministrator" -MockWith { $false }
                
                $result = Install-WSLEnvironment
                Test-ShouldBe $result 1
            }
        }
}

Describe "ConfigureWSL Integration Tests" {
    
    if (-not $script:IsPester5Plus) {
        # Ensure module is loaded for Pester 3.x
        Import-TestModule
    }
    
    It "Should handle complete workflow with mocked dependencies" {
            # Mock all external dependencies for integration test
            Mock -CommandName "Test-IsAdministrator" -MockWith { $true }
            Mock -CommandName "Test-Prerequisites" -MockWith { $true }
            Mock -CommandName "Install-WSLDistribution" -MockWith { $true }
            Mock -CommandName "Install-FiraCodeFont" -MockWith { $true }
            Mock -CommandName "Install-StarshipInWSL" -MockWith { $true }
            Mock -CommandName "Update-WindowsTerminalConfig" -MockWith { $true }
            Mock -CommandName "Update-VSCodeConfig" -MockWith { $true }
            
            $result = Install-WSLEnvironment -LogPath (Get-TestTempPath "integration-test.log")
            Test-ShouldBe $result 0
        }
        
        It "Should handle failures gracefully" {
            # Mock admin check as true but prerequisites as false
            Mock -CommandName "Test-IsAdministrator" -MockWith { $true }
            Mock -CommandName "Test-Prerequisites" -MockWith { $false }
            
            $result = Install-WSLEnvironment -LogPath (Get-TestTempPath "failure-test.log")
            Test-ShouldBe $result 1
        }
}

Describe "ConfigureWSL Error Handling Tests" {
    
    if (-not $script:IsPester5Plus) {
        # Ensure module is loaded for Pester 3.x
        Import-TestModule
    }
    
        It "Should handle file system errors gracefully" {
            # Test logging with invalid path
            Mock -CommandName "Add-Content" -MockWith { throw "Access denied" }
            
            Test-ShouldNotThrow { Write-Log -Message "Test" -Level "INFO" }
        }
        
        It "Should handle network errors in font installation" {
            # Mock web client to throw network error
            Mock -CommandName "New-Object" -ParameterFilter { $TypeName -eq "System.Net.WebClient" } -MockWith {
                throw "Network error"
            }
            
            Test-ShouldNotThrow { Install-FiraCodeFont }
        }
}