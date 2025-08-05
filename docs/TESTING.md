# Testing Guide for ConfigureWSL

This document provides comprehensive information about the testing framework and practices used in the ConfigureWSL PowerShell module.

## Overview

The ConfigureWSL module uses **Pester 5.x** as the primary testing framework, providing comprehensive unit tests, integration tests, and mocking capabilities. The testing strategy focuses on:

- **Unit Testing**: Testing individual functions in isolation
- **Integration Testing**: Testing component interactions
- **Mocking**: Isolating external dependencies
- **Code Coverage**: Ensuring comprehensive test coverage
- **CI/CD Integration**: Automated testing in GitHub Actions

## Test Structure

```
tests/
├── ConfigureWSL.Tests.ps1      # Main test suite
├── Mocks.Tests.ps1             # Advanced mocking tests
├── TestSettings.psd1           # Pester configuration
├── Invoke-Tests.ps1            # Test runner script
└── TestResults/                # Generated test results
    ├── test-results.xml        # NUnit XML format
    └── coverage.xml            # JaCoCo coverage format
```

## Prerequisites

### Required Modules

```powershell
# Install Pester (version 5.0+ recommended)
Install-Module -Name Pester -Force -SkipPublisherCheck

# Install PSScriptAnalyzer for code quality
Install-Module -Name PSScriptAnalyzer -Force -SkipPublisherCheck
```

### System Requirements

- PowerShell 5.1 or later
- Windows 10/11 or Windows Server 2016+
- Administrator privileges (for some integration tests)

## Running Tests

### Basic Test Execution

```powershell
# Run all tests
.\tests\Invoke-Tests.ps1

# Run with code coverage
.\tests\Invoke-Tests.ps1 -Coverage

# Run in CI mode (less verbose output)
.\tests\Invoke-Tests.ps1 -CI

# Run specific tests by tag
.\tests\Invoke-Tests.ps1 -Tag "Unit"
```

### Advanced Test Options

```powershell
# Run tests with custom output path
.\tests\Invoke-Tests.ps1 -OutputPath "C:\TestResults"

# Exclude specific test categories
.\tests\Invoke-Tests.ps1 -ExcludeTag "Integration"

# Run with both coverage and CI mode
.\tests\Invoke-Tests.ps1 -Coverage -CI -OutputPath "./build"
```

### Direct Pester Usage

```powershell
# Import Pester
Import-Module Pester

# Run specific test file
Invoke-Pester -Path ".\tests\ConfigureWSL.Tests.ps1"

# Run with configuration
$config = New-PesterConfiguration
$config.Run.Path = ".\tests\"
$config.CodeCoverage.Enabled = $true
$config.CodeCoverage.Path = ".\src\*.psm1"
Invoke-Pester -Configuration $config
```

## Test Categories

### Unit Tests

**Purpose**: Test individual functions in isolation

**Location**: `tests/ConfigureWSL.Tests.ps1`

**Coverage**:
- Logging functions (`Write-Log`, `Initialize-Logging`)
- Validation functions (`Test-Prerequisites`, `Test-WSLInstallation`, `Test-IsAdministrator`)
- Backup functions (`New-ConfigurationBackup`)
- Configuration functions (`Update-WindowsTerminalConfig`, `Update-VSCodeConfig`)

**Example**:
```powershell
Describe "Write-Log Function" {
    It "Should write INFO message to log file" {
        $testMessage = "This is a test INFO message"
        Write-Log -Message $testMessage -Level "INFO"
        
        $logContent = Get-Content $TestLogPath -Raw
        $logContent | Should -Match "\[INFO\] $testMessage"
    }
}
```

### Integration Tests

**Purpose**: Test component interactions and end-to-end workflows

**Location**: `tests/ConfigureWSL.Tests.ps1` (Integration Tests section)

**Coverage**:
- Complete workflow execution
- Error handling scenarios
- System integration points

**Example**:
```powershell
Describe "Integration Tests" {
    It "Should handle complete workflow with mocked dependencies" {
        Mock -CommandName "Test-IsAdministrator" -MockWith { $true }
        Mock -CommandName "Install-WSLDistribution" -MockWith { $true }
        
        $result = Install-WSLEnvironment -LogPath "$TestDrive\integration-test.log"
        $result | Should -Be 0
    }
}
```

### Mocking Tests

**Purpose**: Test complex scenarios with external dependencies

**Location**: `tests/Mocks.Tests.ps1`

**Coverage**:
- WSL command mocking
- File system operations
- Network operations
- System integration scenarios

**Example**:
```powershell
Describe "WSL Command Mocking" {
    It "Should detect existing WSL distribution" {
        Mock -CommandName "Invoke-Expression" -ParameterFilter { 
            $Command -like "*wsl.exe --list --quiet*" 
        } -MockWith {
            $global:LASTEXITCODE = 0
            return @("Ubuntu", "Ubuntu-20.04")
        }
        
        $result = Install-WSLDistribution -DistroName "Ubuntu"
        $result | Should -Be $true
    }
}
```

## Mocking Strategies

### Command Mocking

```powershell
# Mock external commands
Mock -CommandName "Start-Process" -MockWith {
    return [PSCustomObject]@{ ExitCode = 0 }
}

# Mock with parameter filtering
Mock -CommandName "Invoke-Expression" -ParameterFilter { 
    $Command -like "*wsl.exe*" 
} -MockWith {
    $global:LASTEXITCODE = 0
    return "Success"
}
```

### File System Mocking

```powershell
# Mock file operations
Mock -CommandName "Test-Path" -MockWith { $true }
Mock -CommandName "Get-Content" -MockWith { "Mock content" }
Mock -CommandName "Set-Content" -MockWith { }

# Use TestDrive for temporary files
$testFile = Join-Path $TestDrive "test.txt"
"Test content" | Set-Content $testFile
```

### Network Mocking

```powershell
# Mock web client
$mockWebClient = [PSCustomObject]@{
    Headers = @{ Add = { param($key, $value) } }
    DownloadFile = { param($url, $path) 
        "Mock download" | Set-Content $path
    }
    Dispose = {}
}

Mock -CommandName "New-Object" -ParameterFilter { 
    $TypeName -eq "System.Net.WebClient" 
} -MockWith { return $mockWebClient }
```

## Code Coverage

### Enabling Coverage

Code coverage is automatically enabled when using the `-Coverage` parameter:

```powershell
.\tests\Invoke-Tests.ps1 -Coverage
```

### Coverage Reports

- **JaCoCo XML**: `TestResults/coverage.xml` (for CI/CD integration)
- **Console Output**: Summary displayed after test execution
- **Detailed Analysis**: Missed commands and line coverage

### Coverage Targets

- **Minimum Target**: 70% line coverage
- **Good Target**: 80% line coverage
- **Excellent Target**: 90%+ line coverage

### Analyzing Coverage

```powershell
# View coverage summary
$testResult = Invoke-Pester -Configuration $config
$coveragePercent = $testResult.CodeCoverage.CoveragePercent
Write-Host "Coverage: $coveragePercent%"

# View missed commands
$testResult.CodeCoverage.MissedCommands | ForEach-Object {
    Write-Host "$($_.File):$($_.Line) - $($_.Function)"
}
```

## Test Best Practices

### Writing Good Tests

1. **Descriptive Names**: Use clear, descriptive test names
   ```powershell
   It "Should create backup of existing file" { }
   # Not: It "Should work" { }
   ```

2. **Arrange-Act-Assert Pattern**:
   ```powershell
   It "Should return true for valid input" {
       # Arrange
       $input = "valid-value"
       
       # Act
       $result = Test-Function -Input $input
       
       # Assert
       $result | Should -Be $true
   }
   ```

3. **Use TestDrive**: For temporary files and directories
   ```powershell
   BeforeEach {
       $testFile = Join-Path $TestDrive "test.txt"
       "Content" | Set-Content $testFile
   }
   ```

4. **Proper Cleanup**: Use `BeforeEach` and `AfterEach`
   ```powershell
   AfterEach {
       Remove-Module ConfigureWSL -Force -ErrorAction SilentlyContinue
   }
   ```

### Mocking Guidelines

1. **Mock External Dependencies**: Don't test external systems
2. **Use Parameter Filters**: Make mocks specific
3. **Verify Mock Calls**: Ensure mocks are called as expected
4. **Reset Mocks**: Clean up between tests

### Performance Considerations

1. **Group Related Tests**: Use `Context` blocks
2. **Minimize Setup**: Only set up what's needed
3. **Parallel Execution**: Consider test parallelization
4. **Resource Cleanup**: Always clean up resources

## Troubleshooting Tests

### Common Issues

#### Module Import Failures
```powershell
# Solution: Check module path and dependencies
$ModulePath = Join-Path $PSScriptRoot "..\src\ConfigureWSL.psd1"
Test-Path $ModulePath | Should -Be $true
Import-Module $ModulePath -Force
```

#### Mock Not Working
```powershell
# Solution: Check parameter filters and scope
Mock -CommandName "Test-Function" -MockWith { $true } -ModuleName "ConfigureWSL"
```

#### Test Drive Issues
```powershell
# Solution: Use absolute paths with TestDrive
$testFile = Join-Path $TestDrive "file.txt"
Test-Path $testFile | Should -Be $true
```

### Debugging Tests

```powershell
# Run single test with detailed output
Invoke-Pester -Path ".\tests\ConfigureWSL.Tests.ps1" -Output Detailed

# Debug specific test
Invoke-Pester -Path ".\tests\ConfigureWSL.Tests.ps1" -FullName "*specific test name*"

# Enable debug output
$PesterPreference = [PesterConfiguration]::Default
$PesterPreference.Debug.WriteDebugMessages = $true
```

## CI/CD Integration

The tests are automatically executed in GitHub Actions workflows:

### Continuous Integration (`.github/workflows/ci.yml`)
- Runs on every push and pull request
- Tests on multiple Windows versions
- Includes code coverage and quality checks
- Publishes test results and artifacts

### Code Quality (`.github/workflows/code-quality.yml`)
- PSScriptAnalyzer analysis
- Code metrics calculation
- Documentation quality checks
- Runs weekly and on-demand

### Test Execution in CI

```yaml
- name: Run Tests
  shell: pwsh
  run: |
    $testResult = & ./tests/Invoke-Tests.ps1 -Coverage -CI -OutputPath "./TestResults"
    if ($testResult -ne 0) {
        throw "Tests failed with exit code: $testResult"
    }
```

## Test Data and Fixtures

### Using Test Data

```powershell
# Create test configuration files
BeforeAll {
    $mockSettings = @{
        defaultProfile = "{guid-123}"
        profiles = @{ list = @() }
    } | ConvertTo-Json -Depth 5
    
    $mockSettingsPath = Join-Path $TestDrive "settings.json"
    $mockSettings | Set-Content $mockSettingsPath
}
```

### Fixture Files

Store complex test data in separate files:

```
tests/
├── fixtures/
│   ├── valid-settings.json
│   ├── invalid-settings.json
│   └── sample-manifest.psd1
```

## Continuous Improvement

### Regular Maintenance

1. **Review Coverage**: Identify untested code paths
2. **Update Mocks**: Keep mocks current with external APIs
3. **Refactor Tests**: Improve test maintainability
4. **Performance Monitoring**: Track test execution times

### Adding New Tests

When adding new functionality:

1. Write tests first (TDD approach)
2. Ensure adequate coverage
3. Add both positive and negative test cases
4. Include edge cases and error conditions
5. Update documentation

### Test Metrics

Monitor these metrics over time:
- Test count and coverage percentage
- Test execution time
- Test failure rate
- Code complexity metrics

## Resources

- [Pester Documentation](https://pester.dev/)
- [PowerShell Testing Best Practices](https://docs.microsoft.com/en-us/powershell/scripting/dev-cross-plat/writing-portable-modules)
- [PSScriptAnalyzer Rules](https://github.com/PowerShell/PSScriptAnalyzer)
- [GitHub Actions for PowerShell](https://docs.github.com/en/actions/automating-builds-and-tests/building-and-testing-powershell)