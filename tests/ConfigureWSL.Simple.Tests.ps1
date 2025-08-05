#Requires -Modules Pester

# Simplified test structure for Pester 3.x compatibility
$ModulePath = Join-Path $PSScriptRoot "..\src\ConfigureWSL.psd1"

Describe "ConfigureWSL Module Import Tests" {
    
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
            'Initialize-Logging'
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

Describe "ConfigureWSL Logging Tests" {
    
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
    
    It "Should write INFO message to log file" {
        Initialize-Logging -LogPath $TestLogPath
        $testMessage = "This is a test INFO message"
        Write-Log -Message $testMessage -Level "INFO"
        
        $logContent = Get-Content $TestLogPath -Raw
        $logContent | Should Match "\[INFO\] $testMessage"
    }
    
    It "Should include timestamp in log entry" {
        Initialize-Logging -LogPath $TestLogPath
        $testMessage = "Timestamp test message"
        Write-Log -Message $testMessage -Level "INFO"
        
        $logContent = Get-Content $TestLogPath -Raw
        $logContent | Should Match "\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\]"
    }
}

Describe "ConfigureWSL Validation Tests" {
    
    BeforeEach {
        Import-Module $ModulePath -Force
    }
    
    AfterEach {
        Remove-Module ConfigureWSL -Force -ErrorAction SilentlyContinue
    }
    
    It "Test-WSLInstallation should return PSCustomObject" {
        $result = Test-WSLInstallation
        $result | Should BeOfType [PSCustomObject]
        # Pester 3.x workaround for property checking
        $propertyNames = @($result.PSObject.Properties.Name)
        ($propertyNames -contains "IsInstalled") | Should Be $true
        ($propertyNames -contains "IsEnabled") | Should Be $true
        ($propertyNames -contains "Version") | Should Be $true
    }
    
    It "Test-Prerequisites should return boolean" {
        $result = Test-Prerequisites
        $result | Should BeOfType [System.Boolean]
    }
}