# Development Guide for ConfigureWSL

This guide provides comprehensive information for developers working on the ConfigureWSL PowerShell module.

## Table of Contents

- [Getting Started](#getting-started)
- [Project Structure](#project-structure)
- [Development Environment](#development-environment)
- [Coding Standards](#coding-standards)
- [Testing](#testing)
- [Contributing](#contributing)
- [Release Process](#release-process)

## Getting Started

### Prerequisites

- **PowerShell**: 5.1 or later (PowerShell 7+ recommended)
- **Operating System**: Windows 10/11 or Windows Server 2016+
- **Development Tools**: 
  - Visual Studio Code with PowerShell extension
  - Git for version control
  - Windows Terminal (recommended)

### Initial Setup

1. **Clone the repository**:
   ```bash
   git clone https://github.com/your-username/configure-wsl.git
   cd configure-wsl
   ```

2. **Install development dependencies**:
   ```powershell
   # Required modules for development
   Install-Module -Name Pester -Force -SkipPublisherCheck
   Install-Module -Name PSScriptAnalyzer -Force -SkipPublisherCheck
   Install-Module -Name platyPS -Force -SkipPublisherCheck  # For documentation
   ```

3. **Verify setup**:
   ```powershell
   # Test module import
   Import-Module ./src/ConfigureWSL.psd1 -Force
   Get-Module ConfigureWSL
   
   # Run basic tests
   .\tests\Invoke-Tests.ps1
   ```

## Project Structure

```
configure-wsl/
├── .github/                    # GitHub Actions workflows
│   └── workflows/
│       ├── ci.yml             # Continuous Integration
│       ├── release.yml        # Release automation
│       └── code-quality.yml   # Code quality checks
├── docs/                      # Documentation
│   ├── TESTING.md            # Testing guide
│   ├── CI-CD.md              # CI/CD documentation
│   └── DEVELOPMENT.md        # This file
├── src/                       # Source code
│   ├── ConfigureWSL.psd1     # Module manifest
│   └── ConfigureWSL.psm1     # Main module file
├── tests/                     # Test files
│   ├── ConfigureWSL.Tests.ps1 # Main test suite
│   ├── Mocks.Tests.ps1       # Advanced mocking tests
│   ├── TestSettings.psd1     # Pester configuration
│   └── Invoke-Tests.ps1      # Test runner script
├── configure-wsl.ps1         # Legacy standalone script
├── LICENSE                   # License file
└── README.md                # Project documentation
```

### Module Architecture

The module is organized into functional regions:

```powershell
#region Logging Functions
- Write-Log
- Initialize-Logging

#region Validation Functions  
- Test-IsAdministrator
- Test-WSLInstallation
- Test-Prerequisites

#region Backup Functions
- New-ConfigurationBackup

#region WSL Functions
- Install-WSLDistribution
- Install-StarshipInWSL

#region Font Functions
- Install-FiraCodeFont

#region Configuration Functions
- Update-WindowsTerminalConfig
- Update-VSCodeConfig

#region Main Function
- Install-WSLEnvironment
```

## Development Environment

### Recommended VS Code Extensions

```json
{
  "recommendations": [
    "ms-vscode.powershell",
    "ms-vscode.test-adapter-converter",
    "ms-vscode.test-explorer-ui",
    "streetsidesoftware.code-spell-checker",
    "redhat.vscode-yaml",
    "yzhang.markdown-all-in-one"
  ]
}
```

### VS Code Settings

Create `.vscode/settings.json`:

```json
{
  "powershell.codeFormatting.preset": "OTBS",
  "powershell.codeFormatting.useCorrectCasing": true,
  "powershell.scriptAnalysis.enable": true,
  "powershell.scriptAnalysis.settingsPath": ".vscode/PSScriptAnalyzerSettings.psd1",
  "files.associations": {
    "*.psd1": "powershell",
    "*.psm1": "powershell"
  },
  "files.trimTrailingWhitespace": true,
  "files.insertFinalNewline": true
}
```

### PSScriptAnalyzer Configuration

Create `.vscode/PSScriptAnalyzerSettings.psd1`:

```powershell
@{
    # Enable all rules
    IncludeRules = @('*')
    
    # Exclude specific rules if needed
    ExcludeRules = @(
        # Add rules to exclude here if necessary
    )
    
    # Rule-specific settings
    Rules = @{
        PSProvideCommentHelp = @{
            Enable = $true
            ExportedOnly = $true
            BlockComment = $true
            VSCodeSnippetCorrection = $true
            Placement = "before"
        }
        
        PSPlaceOpenBrace = @{
            Enable = $true
            OnSameLine = $true
            NewLineAfter = $true
            IgnoreOneLineBlock = $true
        }
        
        PSUseConsistentIndentation = @{
            Enable = $true
            Kind = 'space'
            PipelineIndentation = 'IncreaseIndentationAfterEveryPipeline'
            IndentationSize = 4
        }
        
        PSUseConsistentWhitespace = @{
            Enable = $true
            CheckInnerBrace = $true
            CheckOpenBrace = $true
            CheckOpenParen = $true
            CheckOperator = $true
            CheckPipe = $true
            CheckSeparator = $true
            CheckInnerBrace = $true
        }
    }
}
```

### PowerShell Profile Setup

Add to your PowerShell profile for development:

```powershell
# Development aliases
Set-Alias -Name cw -Value "Set-Location C:\path\to\configure-wsl"

# Quick test function
function Test-ConfigureWSL {
    param([switch]$Coverage)
    
    Set-Location C:\path\to\configure-wsl
    if ($Coverage) {
        .\tests\Invoke-Tests.ps1 -Coverage
    } else {
        .\tests\Invoke-Tests.ps1
    }
}

# Quick module reload
function Import-ConfigureWSL {
    Remove-Module ConfigureWSL -Force -ErrorAction SilentlyContinue
    Import-Module ./src/ConfigureWSL.psd1 -Force
}
```

## Coding Standards

### PowerShell Style Guide

#### Function Naming
- Use Pascal case: `Install-WSLDistribution`
- Use approved verbs: `Get-`, `Set-`, `New-`, `Remove-`, `Install-`, `Update-`, `Test-`
- Be descriptive and specific

#### Parameter Guidelines
```powershell
function Example-Function {
    [CmdletBinding()]
    param(
        # Mandatory parameters first
        [Parameter(Mandatory = $true)]
        [string]$RequiredParameter,
        
        # Optional parameters
        [Parameter(Mandatory = $false)]
        [string]$OptionalParameter = "DefaultValue",
        
        # Use proper parameter attributes
        [Parameter(Mandatory = $false)]
        [ValidateSet("Option1", "Option2")]
        [string]$ValidatedParameter,
        
        # Switch parameters
        [Parameter(Mandatory = $false)]
        [switch]$SwitchParameter
    )
}
```

#### Error Handling
```powershell
function Example-Function {
    [CmdletBinding()]
    param(...)
    
    try {
        # Main logic here
        $result = Invoke-SomeOperation
        
        if (-not $result) {
            Write-Log "Operation failed" -Level "ERROR"
            return $false
        }
        
        Write-Log "Operation succeeded" -Level "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Error in Example-Function: $_" -Level "ERROR"
        return $false
    }
}
```

#### Documentation Standards
```powershell
function Install-WSLDistribution {
    <#
    .SYNOPSIS
        Install WSL distribution if not present
    .DESCRIPTION
        Installs the specified WSL distribution using modern WSL commands.
        Checks for existing installations and handles automated setup.
    .PARAMETER DistroName
        Name of the WSL distribution to install (e.g., "Ubuntu", "Ubuntu-22.04")
    .OUTPUTS
        System.Boolean - True if installation succeeded, False otherwise
    .EXAMPLE
        Install-WSLDistribution -DistroName "Ubuntu"
        Installs the Ubuntu distribution
    .EXAMPLE
        Install-WSLDistribution -DistroName "Ubuntu-22.04"
        Installs a specific Ubuntu version
    .NOTES
        Requires Administrator privileges and functional WSL installation
    #>
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DistroName
    )
    
    # Function implementation...
}
```

### Code Organization

#### Region Usage
```powershell
#region Logging Functions
function Write-Log { ... }
function Initialize-Logging { ... }
#endregion

#region Helper Functions
function Get-SystemInfo { ... }
#endregion
```

#### Variable Naming
- Use camelCase for local variables: `$logPath`, `$installResult`
- Use PascalCase for parameters: `$DistroName`, `$LogPath`  
- Use descriptive names: `$wslInstallationResult` not `$result`

#### Constants and Module Variables
```powershell
# Module-level variables
$script:LogPath = $null
$script:BackupDirectory = $null

# Constants (use uppercase with underscores)
$DEFAULT_DISTRO_NAME = "Ubuntu"
$FONT_DOWNLOAD_URL = "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip"
```

## Testing

### Test-Driven Development

1. **Write tests first** for new functionality
2. **Ensure tests fail** initially (red)
3. **Implement minimum code** to pass tests (green)
4. **Refactor** while keeping tests passing (refactor)

### Test Categories

#### Unit Tests
```powershell
Describe "Function Unit Tests" {
    Context "When given valid input" {
        It "Should return expected result" {
            # Arrange
            $input = "valid-input"
            
            # Act
            $result = Test-Function -Input $input
            
            # Assert
            $result | Should -Be $true
        }
    }
    
    Context "When given invalid input" {
        It "Should handle error gracefully" {
            # Arrange
            $input = $null
            
            # Act & Assert
            { Test-Function -Input $input } | Should -Not -Throw
        }
    }
}
```

#### Integration Tests
```powershell
Describe "Integration Tests" {
    BeforeAll {
        # Setup test environment
        Import-Module ./src/ConfigureWSL.psd1 -Force
    }
    
    AfterAll {
        # Cleanup
        Remove-Module ConfigureWSL -Force -ErrorAction SilentlyContinue
    }
    
    It "Should execute complete workflow" {
        # Mock external dependencies
        Mock -CommandName "Test-IsAdministrator" -MockWith { $true }
        
        # Test integration
        $result = Install-WSLEnvironment -SkipFontInstall -SkipStarship
        $result | Should -Be 0
    }
}
```

### Mocking Best Practices

```powershell
# Mock external commands
Mock -CommandName "Start-Process" -MockWith {
    return [PSCustomObject]@{ ExitCode = 0 }
}

# Mock with parameter filtering
Mock -CommandName "Invoke-RestMethod" -ParameterFilter {
    $Uri -like "*github.com*"
} -MockWith {
    return @{ tag_name = "v1.0.0" }
}

# Verify mock calls
It "Should call external command" {
    Test-Function
    Assert-MockCalled -CommandName "Start-Process" -Times 1
}
```

### Running Tests

```powershell
# Run all tests
.\tests\Invoke-Tests.ps1

# Run with coverage
.\tests\Invoke-Tests.ps1 -Coverage

# Run specific test file
Invoke-Pester -Path "./tests/ConfigureWSL.Tests.ps1"

# Run specific test
Invoke-Pester -Path "./tests/ConfigureWSL.Tests.ps1" -FullName "*Write-Log*"
```

## Contributing

### Workflow

1. **Fork** the repository
2. **Create feature branch**: `git checkout -b feature/new-functionality`
3. **Make changes** following coding standards
4. **Write tests** for new functionality
5. **Run tests**: `.\tests\Invoke-Tests.ps1 -Coverage`
6. **Run code analysis**: `Invoke-ScriptAnalyzer -Path ./src/ConfigureWSL.psm1`
7. **Commit changes**: `git commit -m "Add new functionality"`
8. **Push branch**: `git push origin feature/new-functionality`
9. **Create pull request**

### Pull Request Guidelines

#### Title Format
- Use descriptive titles
- Start with action verb: "Add", "Fix", "Update", "Remove"
- Examples:
  - "Add support for Ubuntu 24.04"
  - "Fix WSL installation detection logic"
  - "Update Starship installation script"

#### Description Template
```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update

## Testing
- [ ] Tests pass locally
- [ ] New tests added for new functionality
- [ ] Code coverage maintained or improved

## Checklist
- [ ] Code follows project style guidelines
- [ ] Self-review of code completed  
- [ ] Code is commented, particularly in hard-to-understand areas
- [ ] Documentation updated if needed
- [ ] No new warnings from PSScriptAnalyzer
```

### Code Review Process

#### For Reviewers

1. **Functionality**: Does the code work as intended?
2. **Style**: Does it follow project conventions?
3. **Tests**: Are there adequate tests?
4. **Documentation**: Is documentation updated?
5. **Performance**: Any performance implications?
6. **Security**: Any security concerns?

#### Common Review Comments

```powershell
# ❌ Avoid
$result = Get-Something
if ($result -eq $null) { ... }

# ✅ Prefer
$result = Get-Something
if (-not $result) { ... }

# ❌ Avoid
function DoSomething() { ... }

# ✅ Prefer  
function Invoke-Something {
    [CmdletBinding()]
    param(...)
    ...
}
```

## Release Process

### Version Management

1. **Determine version** following semantic versioning:
   - **Patch**: Bug fixes (1.0.0 → 1.0.1)
   - **Minor**: New features (1.0.0 → 1.1.0)
   - **Major**: Breaking changes (1.0.0 → 2.0.0)

2. **Update CHANGELOG.md** with new version details

3. **Create release**:
   ```bash
   # Tag release
   git tag v1.2.0
   git push origin v1.2.0
   
   # Or use GitHub CLI
   gh release create v1.2.0 --generate-notes
   ```

### Release Checklist

- [ ] All tests pass
- [ ] Code coverage acceptable (>80%)
- [ ] Documentation updated
- [ ] CHANGELOG.md updated
- [ ] Version bumped in manifest
- [ ] No breaking changes (or properly documented)
- [ ] Security review completed

## Debugging

### Common Issues

#### Module Import Problems
```powershell
# Check manifest syntax
Test-ModuleManifest -Path ./src/ConfigureWSL.psd1

# Import with verbose output
Import-Module ./src/ConfigureWSL.psd1 -Force -Verbose

# Check for syntax errors
$ast = [System.Management.Automation.Parser]::ParseFile(
    "./src/ConfigureWSL.psm1", 
    [ref]$null, 
    [ref]$null
)
```

#### Test Failures
```powershell
# Run single failing test
Invoke-Pester -Path "./tests/ConfigureWSL.Tests.ps1" -FullName "*failing test name*"

# Debug with detailed output
Invoke-Pester -Path "./tests/ConfigureWSL.Tests.ps1" -Output Detailed

# Check mock calls
Mock -CommandName "Test-Function" -MockWith { $true }
# ... run test ...
Assert-MockCalled -CommandName "Test-Function" -Exactly 1
```

### Development Tools

#### Interactive Debugging
```powershell
# Set breakpoint
Set-PSBreakpoint -Script "./src/ConfigureWSL.psm1" -Line 100

# Step through code
Enable-PSBreakpoint -Id 1
Install-WSLEnvironment  # This will hit breakpoint
```

#### Profiling
```powershell
# Measure execution time
Measure-Command { Install-WSLEnvironment -SkipFontInstall -SkipStarship }

# Profile specific functions
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
Test-WSLInstallation
$stopwatch.Stop()
Write-Host "Execution time: $($stopwatch.ElapsedMilliseconds)ms"
```

## Resources

### Documentation
- [PowerShell Best Practices](https://docs.microsoft.com/en-us/powershell/scripting/developer/cmdlet/strongly-encouraged-development-guidelines)
- [PowerShell Style Guide](https://poshcode.gitbook.io/powershell-practice-and-style/)
- [Pester Documentation](https://pester.dev/)
- [GitHub Flow](https://guides.github.com/introduction/flow/)

### Tools
- [PowerShell extension for VS Code](https://marketplace.visualstudio.com/items?itemName=ms-vscode.PowerShell)
- [PSScriptAnalyzer](https://github.com/PowerShell/PSScriptAnalyzer)
- [platyPS](https://github.com/PowerShell/platyPS) for help documentation

### Community
- [PowerShell Discord](https://discord.gg/powershell)
- [r/PowerShell](https://reddit.com/r/PowerShell)
- [PowerShell GitHub Discussions](https://github.com/PowerShell/PowerShell/discussions)