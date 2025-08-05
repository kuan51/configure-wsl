#Requires -Modules Pester

# Pester 3.x/5.x compatible test file for ConfigureWSL module
$ModulePath = Join-Path $PSScriptRoot "..\src\ConfigureWSL.psd1"

Describe "ConfigureWSL Module Import" {
    
    It "Should import the module successfully" {
        Import-Module $ModulePath -Force
        $module = Get-Module ConfigureWSL
        $module | Should Not BeNullOrEmpty
        Remove-Module ConfigureWSL -Force -ErrorAction SilentlyContinue
    }
    
    It "Should export all expected functions" {
        Import-Module $ModulePath -Force
        
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
        
        $exportedFunctions = @((Get-Module ConfigureWSL).ExportedFunctions.Keys)
        
        foreach ($function in $expectedFunctions) {
            $functionExists = $function -in $exportedFunctions
            if (-not $functionExists) {
                $functionExists = ($exportedFunctions | Where-Object { $_ -eq $function }) -ne $null
            }
            $functionExists | Should Be $true
        }
        
        Remove-Module ConfigureWSL -Force -ErrorAction SilentlyContinue
    }
}

Describe "ConfigureWSL Logging Functions" {
    
    BeforeEach {
        Import-Module $ModulePath -Force
        $TestLogPath = Join-Path ([System.IO.Path]::GetTempPath()) "test-log-$(Get-Random).log"
    }
    
    AfterEach {
        if ($TestLogPath -and (Test-Path $TestLogPath)) {
            Remove-Item $TestLogPath -Force -ErrorAction SilentlyContinue
        }
        Remove-Module ConfigureWSL -Force -ErrorAction SilentlyContinue
    }
    
    It "Should create log file" {
        Initialize-Logging -LogPath $TestLogPath
        Test-Path $TestLogPath | Should Be $true
    }
    
    It "Should create log directory if it doesn't exist" {
        $TestLogDir = Join-Path ([System.IO.Path]::GetTempPath()) "NewLogDir-$(Get-Random)"
        $TestLogPath = Join-Path $TestLogDir "test.log"
        Initialize-Logging -LogPath $TestLogPath
        Test-Path $TestLogDir | Should Be $true
        Test-Path $TestLogPath | Should Be $true
        
        # Cleanup
        Remove-Item $TestLogDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    It "Should write initialization message to log" {
        Initialize-Logging -LogPath $TestLogPath
        $logContent = Get-Content $TestLogPath -Raw
        $logContent | Should Match "WSL Configuration Module Started"
    }
    
    It "Should write INFO message to log file" {
        Initialize-Logging -LogPath $TestLogPath
        $testMessage = "This is a test INFO message"
        Write-Log -Message $testMessage -Level "INFO"
        
        $logContent = Get-Content $TestLogPath -Raw
        $logContent | Should Match "\[INFO\] $testMessage"
    }
    
    It "Should write SUCCESS message to log file" {
        Initialize-Logging -LogPath $TestLogPath
        $testMessage = "This is a test SUCCESS message"
        Write-Log -Message $testMessage -Level "SUCCESS"
        
        $logContent = Get-Content $TestLogPath -Raw
        $logContent | Should Match "\[SUCCESS\] $testMessage"
    }
    
    It "Should write WARN message to log file" {
        Initialize-Logging -LogPath $TestLogPath
        $testMessage = "This is a test WARN message"
        Write-Log -Message $testMessage -Level "WARN"
        
        $logContent = Get-Content $TestLogPath -Raw
        $logContent | Should Match "\[WARN\] $testMessage"
    }
    
    It "Should include timestamp in log entry" {
        Initialize-Logging -LogPath $TestLogPath
        $testMessage = "Timestamp test message"
        Write-Log -Message $testMessage -Level "INFO"
        
        $logContent = Get-Content $TestLogPath -Raw
        $logContent | Should Match "\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\]"
    }
    
    It "Should handle empty log path gracefully" {
        # Temporarily clear the log path
        $originalLogPath = $script:LogPath
        $script:LogPath = $null
        
        { Write-Log -Message "Test message" -Level "INFO" } | Should Not Throw
        
        # Restore log path
        $script:LogPath = $originalLogPath
    }
}

Describe "ConfigureWSL Validation Functions" {
    
    BeforeEach {
        Import-Module $ModulePath -Force
    }
    
    AfterEach {
        Remove-Module ConfigureWSL -Force -ErrorAction SilentlyContinue
    }
    
    It "Test-WSLInstallation should return PSCustomObject with required properties" {
        $result = Test-WSLInstallation
        $result | Should BeOfType [PSCustomObject]
        
        # Pester 3.x workaround for property checking
        $propertyNames = @($result.PSObject.Properties.Name)
        ($propertyNames -contains "IsInstalled") | Should Be $true
        ($propertyNames -contains "IsEnabled") | Should Be $true
        ($propertyNames -contains "Version") | Should Be $true
    }
    
    It "Test-WSLInstallation should return boolean values for IsInstalled and IsEnabled" {
        $result = Test-WSLInstallation
        $result.IsInstalled | Should BeOfType [System.Boolean]
        $result.IsEnabled | Should BeOfType [System.Boolean]
    }
    
    It "Test-WSLInstallation should not throw exceptions" {
        { Test-WSLInstallation } | Should Not Throw
    }
    
    It "Test-Prerequisites should return boolean value" {
        $result = Test-Prerequisites
        $result | Should BeOfType [System.Boolean]
    }
    
    It "Test-Prerequisites should not throw exceptions" {
        { Test-Prerequisites } | Should Not Throw
    }
}

Describe "ConfigureWSL WSL Functions" {
    
    BeforeEach {
        Import-Module $ModulePath -Force
    }
    
    AfterEach {
        Remove-Module ConfigureWSL -Force -ErrorAction SilentlyContinue
    }
    
    It "Install-WSLDistribution should accept DistroName parameter" {
        $securePassword = ConvertTo-SecureString "testpass" -AsPlainText -Force
        { Install-WSLDistribution -DistroName "Ubuntu" -Username "testuser" -Password $securePassword } | Should Not Throw
    }
    
    It "Install-WSLDistribution should return boolean value" {
        # Mock the WSL commands to avoid actual installation
        Mock -CommandName "Start-Process" -MockWith { 
            return [PSCustomObject]@{ ExitCode = 0 }
        }
        Mock -CommandName "Invoke-Expression" -MockWith { 
            $global:LASTEXITCODE = 0
            return @("Ubuntu")
        }
        
        $securePassword = ConvertTo-SecureString "testpass" -AsPlainText -Force
        $result = Install-WSLDistribution -DistroName "Ubuntu" -Username "testuser" -Password $securePassword
        $result | Should BeOfType [System.Boolean]
    }
    
    It "Install-StarshipInWSL should accept DistroName parameter" {
        { Install-StarshipInWSL -DistroName "Ubuntu" -Username "testuser" } | Should Not Throw
    }
    
    It "Install-StarshipInWSL should return boolean value" {
        # Mock WSL commands
        Mock -CommandName "Start-Process" -MockWith { 
            return [PSCustomObject]@{ ExitCode = 0 }
        }
        Mock -CommandName "Invoke-Expression" -MockWith { 
            $global:LASTEXITCODE = 0
        }
        
        $result = Install-StarshipInWSL -DistroName "Ubuntu" -Username "testuser"
        $result | Should BeOfType [System.Boolean]
    }
    
    It "Get-WSLErrorMessage should return string value" {
        $result = Get-WSLErrorMessage -ExitCode -1
        $result | Should BeOfType [System.String]
    }
    
    It "Get-WSLErrorMessage should handle error code -1 with specific error output" {
        $result = Get-WSLErrorMessage -ExitCode -1 -ErrorOutput "Error: 0x8000000d"
        ($result -like "*Another WSL operation*") | Should Be $true
    }
    
    It "Test-WSLDistributionState should accept DistroName parameter" {
        { Test-WSLDistributionState -DistroName "Ubuntu" } | Should Not Throw
    }
    
    It "Test-WSLDistributionState should return boolean value" {
        # Mock WSL command to avoid actual checking
        Mock -CommandName "Invoke-Expression" -MockWith { 
            return $null
        }
        
        $result = Test-WSLDistributionState -DistroName "Ubuntu"
        $result | Should BeOfType [System.Boolean]
    }
    
    It "Set-WSLWelcomeMessage should accept DistroName and Username parameters" {
        { Set-WSLWelcomeMessage -DistroName "Ubuntu" -Username "testuser" } | Should Not Throw
    }
    
    It "Set-WSLWelcomeMessage should return boolean value" {
        # Mock WSL command to avoid actual execution
        Mock -CommandName "Invoke-Expression" -MockWith { 
            $global:LASTEXITCODE = 0
        }
        
        $result = Set-WSLWelcomeMessage -DistroName "Ubuntu" -Username "testuser"
        $result | Should BeOfType [System.Boolean]
    }
}

Describe "ConfigureWSL Font Functions" {
    
    BeforeEach {
        Import-Module $ModulePath -Force
    }
    
    AfterEach {
        Remove-Module ConfigureWSL -Force -ErrorAction SilentlyContinue
    }
    
    It "Install-FiraCodeFont should return boolean value" {
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
        $result | Should BeOfType [System.Boolean]
    }
    
    It "Install-FiraCodeFont should not throw exceptions during mocked execution" {
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
        
        { Install-FiraCodeFont } | Should Not Throw
    }
}

Describe "ConfigureWSL Configuration Functions" {
    
    BeforeEach {
        Import-Module $ModulePath -Force
    }
    
    AfterEach {
        Remove-Module ConfigureWSL -Force -ErrorAction SilentlyContinue
    }
    
    It "Update-WindowsTerminalConfig should return boolean value" {
        $result = Update-WindowsTerminalConfig
        $result | Should BeOfType [System.Boolean]
    }
    
    It "Update-WindowsTerminalConfig should handle missing settings file gracefully" {
        # Mock Test-Path to return false for settings file
        Mock -CommandName "Test-Path" -MockWith { $false }
        
        $result = Update-WindowsTerminalConfig
        $result | Should Be $false
    }
    
    It "Update-VSCodeConfig should return boolean value" {
        $result = Update-VSCodeConfig
        $result | Should BeOfType [System.Boolean]
    }
    
    It "Update-VSCodeConfig should handle missing settings file gracefully" {
        # Mock Test-Path to return false for all possible settings paths
        Mock -CommandName "Test-Path" -MockWith { $false }
        
        $result = Update-VSCodeConfig
        $result | Should Be $false
    }
}

Describe "ConfigureWSL Main Function" {
    
    BeforeEach {
        Import-Module $ModulePath -Force
    }
    
    AfterEach {
        Remove-Module ConfigureWSL -Force -ErrorAction SilentlyContinue
    }
    
    It "Install-WSLEnvironment should accept all parameters" {
        $testLogPath = Join-Path ([System.IO.Path]::GetTempPath()) "test-$(Get-Random).log"
        { Install-WSLEnvironment -DistroName "Ubuntu" -SkipFontInstall -SkipStarship -LogPath $testLogPath } | Should Not Throw
        
        # Cleanup
        if (Test-Path $testLogPath) {
            Remove-Item $testLogPath -Force -ErrorAction SilentlyContinue
        }
    }
    
    It "Install-WSLEnvironment should return integer exit code" {
        # Mock administrator check to return false to avoid actual execution
        Mock -CommandName "Test-IsAdministrator" -MockWith { $false }
        
        $result = Install-WSLEnvironment
        $result | Should BeOfType [System.Int32]
    }
    
    It "Install-WSLEnvironment should return 1 when not running as administrator" {
        # Mock administrator check to return false
        Mock -CommandName "Test-IsAdministrator" -MockWith { $false }
        
        $result = Install-WSLEnvironment
        $result | Should Be 1
    }
}

Describe "ConfigureWSL Integration Tests" {
    
    BeforeEach {
        Import-Module $ModulePath -Force
    }
    
    AfterEach {
        Remove-Module ConfigureWSL -Force -ErrorAction SilentlyContinue
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
        
        $testLogPath = Join-Path ([System.IO.Path]::GetTempPath()) "integration-test-$(Get-Random).log"
        $result = Install-WSLEnvironment -LogPath $testLogPath
        $result | Should Be 0
        
        # Cleanup
        if (Test-Path $testLogPath) {
            Remove-Item $testLogPath -Force -ErrorAction SilentlyContinue
        }
    }
    
    It "Should handle failures gracefully" {
        # Mock admin check as true but prerequisites as false
        Mock -CommandName "Test-IsAdministrator" -MockWith { $true }
        Mock -CommandName "Test-Prerequisites" -MockWith { $false }
        
        $testLogPath = Join-Path ([System.IO.Path]::GetTempPath()) "failure-test-$(Get-Random).log"
        $result = Install-WSLEnvironment -LogPath $testLogPath
        $result | Should Be 1
        
        # Cleanup
        if (Test-Path $testLogPath) {
            Remove-Item $testLogPath -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe "ConfigureWSL Error Handling Tests" {
    
    BeforeEach {
        Import-Module $ModulePath -Force
    }
    
    AfterEach {
        Remove-Module ConfigureWSL -Force -ErrorAction SilentlyContinue
    }
    
    It "Should handle file system errors gracefully" {
        # Test logging with invalid path
        Mock -CommandName "Add-Content" -MockWith { throw "Access denied" }
        
        { Write-Log -Message "Test" -Level "INFO" } | Should Not Throw
    }
    
    It "Should handle network errors in font installation" {
        # Mock web client to throw network error
        Mock -CommandName "New-Object" -ParameterFilter { $TypeName -eq "System.Net.WebClient" } -MockWith {
            throw "Network error"
        }
        
        { Install-FiraCodeFont } | Should Not Throw
    }
}