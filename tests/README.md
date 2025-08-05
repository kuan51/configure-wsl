# ConfigureWSL Testing Guide

This guide explains how to run tests for the ConfigureWSL module and provides information about Pester version compatibility.

## Quick Start

To run all tests with default settings:

```powershell
.\tests\Invoke-Tests.ps1
```

## Pester Version Compatibility

The test suite is designed to work with both **Pester 3.x** and **Pester 5.x** versions. The test runner automatically detects your Pester version and adapts accordingly.

### Current Support

- **Pester 3.4.0+**: Fully supported with compatibility layer
- **Pester 5.0.0+**: Native support with advanced features

### Checking Your Pester Version

```powershell
Get-Module -Name Pester -ListAvailable | Select-Object Name, Version
```

## Test Runner Options

### Basic Usage

```powershell
# Run all tests
.\Invoke-Tests.ps1

# Run tests with code coverage
.\Invoke-Tests.ps1 -Coverage

# Run tests in CI mode
.\Invoke-Tests.ps1 -CI

# Run specific test tags
.\Invoke-Tests.ps1 -Tag "Unit"

# Exclude specific test tags
.\Invoke-Tests.ps1 -ExcludeTag "Integration"

# Custom output path
.\Invoke-Tests.ps1 -OutputPath ".\custom-results"
```

### Advanced Usage

```powershell
# Comprehensive test run with coverage for CI
.\Invoke-Tests.ps1 -Coverage -CI -OutputPath ".\build\test-results"

# Run only unit tests with coverage
.\Invoke-Tests.ps1 -Coverage -Tag "Unit" -ExcludeTag "Integration,Mock"
```

## Upgrading to Pester 5.x

While the tests work with Pester 3.x, **Pester 5.x is strongly recommended** for the best testing experience and access to advanced features.

### Why Upgrade?

- **Better Performance**: Faster test execution
- **Enhanced Code Coverage**: More detailed coverage reporting
- **Improved Output**: Better formatted test results
- **Modern Features**: Block-scoped setup/teardown, parallel execution
- **Active Development**: Continued updates and bug fixes

### Installation Steps

#### Method 1: PowerShell Gallery (Recommended)

```powershell
# Remove old Pester version (if needed)
Uninstall-Module -Name Pester -AllVersions -Force

# Install latest Pester
Install-Module -Name Pester -Force -SkipPublisherCheck -Scope CurrentUser

# Verify installation
Get-Module -Name Pester -ListAvailable
```

#### Method 2: For System-Wide Installation

```powershell
# Run as Administrator
Install-Module -Name Pester -Force -SkipPublisherCheck -Scope AllUsers
```

#### Method 3: Offline Installation

If you're in a restricted environment:

1. Download Pester from [PowerShell Gallery](https://www.powershellgallery.com/packages/Pester)
2. Extract to your PowerShell modules directory
3. Import manually: `Import-Module Pester -Force`

### Troubleshooting Upgrade Issues

#### Module Conflicts

```powershell
# Check for multiple Pester versions
Get-Module -Name Pester -ListAvailable | Format-Table Name, Version, ModuleBase

# Remove all versions and reinstall
Get-Module -Name Pester -ListAvailable | Uninstall-Module -Force
Install-Module -Name Pester -Force -SkipPublisherCheck
```

#### Import Issues

```powershell
# Force remove and reimport
Remove-Module -Name Pester -Force -ErrorAction SilentlyContinue
Import-Module -Name Pester -Force
```

#### Permission Issues

```powershell
# Install with different execution policy temporarily
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process
Install-Module -Name Pester -Force -SkipPublisherCheck
```

## Test Files Structure

```
tests/
├── Invoke-Tests.ps1           # Test runner with version compatibility
├── ConfigureWSL.Tests.ps1     # Main module tests
├── Mocks.Tests.ps1           # Advanced mocking tests
└── README.md                 # This file
```

## Test Categories

### Unit Tests
Test individual functions in isolation with mocked dependencies.

```powershell
.\Invoke-Tests.ps1 -Tag "Unit"
```

### Integration Tests
Test complete workflows with mocked external systems.

```powershell
.\Invoke-Tests.ps1 -Tag "Integration"
```

### Mock Tests
Advanced testing scenarios with comprehensive mocking.

```powershell
.\Invoke-Tests.ps1 -Tag "Mock"
```

## Continuous Integration

The test runner supports CI environments with appropriate output formatting:

```powershell
.\Invoke-Tests.ps1 -CI -Coverage -OutputPath ".\build\test-results"
```

### Output Files

- **test-results.xml**: NUnit-format test results
- **coverage.xml**: JaCoCo-format code coverage (when `-Coverage` is used)

## Common Issues and Solutions

### Issue: "Cannot convert 'System.Object[]' to 'System.String'"

**Solution**: This is fixed in the updated test runner. Ensure you're using the latest version.

### Issue: BeforeAll/AfterAll not recognized

**Solution**: This indicates Pester 3.x. The tests now include compatibility layers for this.

### Issue: Tests fail with path-related errors

**Solution**: Ensure you're running tests from the correct directory and that all module files exist.

### Issue: Module import failures

**Solution**: 
```powershell
# Verify module structure
Test-Path ".\src\ConfigureWSL.psd1"
Test-Path ".\src\ConfigureWSL.psm1"

# Import manually to check for syntax errors
Import-Module ".\src\ConfigureWSL.psd1" -Force
```

## Best Practices

1. **Run tests before commits**: Always run the full test suite before committing changes
2. **Use code coverage**: Run with `-Coverage` to identify untested code
3. **Tag your tests**: Use appropriate tags for selective test execution
4. **Update Pester**: Keep Pester updated for the best experience
5. **Monitor CI results**: Check test results in CI environments

## Support

If you encounter issues:

1. Check this README for solutions
2. Verify your Pester version compatibility
3. Review test output for specific error messages
4. Check module import success manually

For Pester-specific issues, refer to the [official Pester documentation](https://pester.dev/).