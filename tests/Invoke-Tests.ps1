#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Test runner script for ConfigureWSL module
.DESCRIPTION
    Executes all tests for the ConfigureWSL module using Pester 5.x framework.
    Supports code coverage analysis and CI/CD integration.
.PARAMETER Coverage
    Enable code coverage analysis
.PARAMETER CI
    Run in CI mode with appropriate output formatting
.PARAMETER OutputPath
    Path for test results output
.PARAMETER Tag
    Run only tests with specific tags
.PARAMETER ExcludeTag
    Exclude tests with specific tags
.EXAMPLE
    .\Invoke-Tests.ps1
    Run all tests with default settings
.EXAMPLE
    .\Invoke-Tests.ps1 -Coverage -CI
    Run tests with code coverage in CI mode
.EXAMPLE
    .\Invoke-Tests.ps1 -Tag "Unit" -OutputPath ".\results"
    Run only unit tests with custom output path
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$Coverage,
    
    [Parameter(Mandatory = $false)]
    [switch]$CI,
    
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = ".",
    
    [Parameter(Mandatory = $false)]
    [string[]]$Tag = @(),
    
    [Parameter(Mandatory = $false)]
    [string[]]$ExcludeTag = @()
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Get script directory
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptRoot

Write-Host "=== ConfigureWSL Module Test Runner ===" -ForegroundColor Cyan
Write-Host "Project Root: $ProjectRoot" -ForegroundColor Gray
Write-Host "Test Directory: $ScriptRoot" -ForegroundColor Gray

# Check for Pester module
try {
    $pesterModule = Get-Module -Name Pester -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
    if (-not $pesterModule) {
        throw "Pester module not found"
    }
    
    if ($pesterModule.Version -lt [Version]"5.0.0") {
        Write-Warning "Pester version $($pesterModule.Version) detected. Version 5.0+ is recommended."
        Write-Host "To install latest Pester: Install-Module -Name Pester -Force -SkipPublisherCheck" -ForegroundColor Yellow
    }
    
    Write-Host "Using Pester version: $($pesterModule.Version)" -ForegroundColor Green
    Import-Module Pester -Force
}
catch {
    Write-Error "Failed to load Pester module: $_"
    Write-Host "To install Pester: Install-Module -Name Pester -Force -SkipPublisherCheck" -ForegroundColor Yellow
    exit 1
}

# Prepare output directory
# Handle edge case where OutputPath parameter gets corrupted
if (-not $OutputPath -or $OutputPath -match '^\d+$') {
    $OutputPath = "."
}

$TestResultsPath = Join-Path $OutputPath "TestResults"
if (-not (Test-Path $TestResultsPath)) {
    New-Item -Path $TestResultsPath -ItemType Directory -Force | Out-Null
}

# Detect Pester version and build appropriate configuration
$isPester5Plus = $pesterModule.Version -ge [Version]"5.0.0"

# Get test files (fix array-to-string conversion issue)
# Use the compatible test files that work with both Pester versions
$testFiles = Get-ChildItem -Path $ScriptRoot -Filter "*.Compatible.Tests.ps1" | Select-Object -ExpandProperty FullName
if ($testFiles.Count -eq 0) {
    # Fallback to simple tests if compatible tests don't exist
    $testFiles = Get-ChildItem -Path $ScriptRoot -Filter "*.Simple.Tests.ps1" | Select-Object -ExpandProperty FullName
}
if ($testFiles.Count -eq 0) {
    # Final fallback to all test files
    $testFiles = Get-ChildItem -Path $ScriptRoot -Filter "*.Tests.ps1" | Select-Object -ExpandProperty FullName
}
Write-Host "Found test files: $($testFiles.Count)" -ForegroundColor Gray

if ($isPester5Plus) {
    Write-Host "Using Pester 5.x configuration syntax" -ForegroundColor Green
    
    # Build Pester 5.x configuration
    $pesterConfig = @{
        Run = @{
            Path = $testFiles
            PassThru = $true
        }
        Output = @{
            Verbosity = if ($CI) { 'Normal' } else { 'Detailed' }
            StackTraceVerbosity = 'Filtered'
            CIFormat = if ($CI) { 'Auto' } else { 'None' }
        }
        TestResult = @{
            Enabled = $true
            OutputFormat = 'NUnitXml'
            OutputPath = Join-Path $TestResultsPath "test-results.xml"
            OutputEncoding = 'UTF8'
            TestSuiteName = 'ConfigureWSL'
        }
        Should = @{
            ErrorAction = 'Stop'
        }
    }
    
    # Add filtering if specified
    if ($Tag.Count -gt 0) {
        $pesterConfig.Filter = @{ Tag = $Tag }
    }
    if ($ExcludeTag.Count -gt 0) {
        if (-not $pesterConfig.Filter) { $pesterConfig.Filter = @{} }
        $pesterConfig.Filter.ExcludeTag = $ExcludeTag
    }
    
    # Add code coverage if requested
    if ($Coverage) {
        Write-Host "Enabling code coverage analysis..." -ForegroundColor Yellow
        $pesterConfig.CodeCoverage = @{
            Enabled = $true
            Path = @(
                (Join-Path $ProjectRoot "src\*.psm1"),
                (Join-Path $ProjectRoot "src\*.ps1")
            )
            OutputFormat = 'JaCoCo'
            OutputPath = Join-Path $TestResultsPath "coverage.xml"
            OutputEncoding = 'UTF8'
            UseBreakpoints = $false
            SingleHitBreakpoints = $true
        }
    }
} else {
    Write-Host "Using Pester 3.x parameter syntax" -ForegroundColor Yellow
    
    # Build Pester 3.x parameters
    $pesterParams = @{
        Script = $testFiles
        PassThru = $true
        OutputFile = Join-Path $TestResultsPath "test-results.xml"
        OutputFormat = 'NUnitXml'
    }
    
    # Add filtering if specified
    if ($Tag.Count -gt 0) {
        $pesterParams.Tag = $Tag
    }
    if ($ExcludeTag.Count -gt 0) {
        $pesterParams.ExcludeTag = $ExcludeTag
    }
    
    # Add code coverage if requested (Pester 3.x syntax)
    if ($Coverage) {
        Write-Host "Enabling code coverage analysis..." -ForegroundColor Yellow
        $pesterParams.CodeCoverage = @(
            (Join-Path $ProjectRoot "src\*.psm1"),
            (Join-Path $ProjectRoot "src\*.ps1")
        )
        # Note: Pester 3.x only supports basic code coverage through PassThru result object
        # No direct output file parameter exists for code coverage in 3.x
    }
}

# Set working directory to project root
Push-Location $ProjectRoot

try {
    Write-Host "Starting test execution..." -ForegroundColor Green
    
    # Display test file count based on Pester version
    if ($isPester5Plus) {
        Write-Host "Test files: $(($pesterConfig.Run.Path | Measure-Object).Count)" -ForegroundColor Gray
    } else {
        Write-Host "Test files: $(($pesterParams.Script | Measure-Object).Count)" -ForegroundColor Gray
    }
    
    # Run tests using appropriate syntax
    if ($isPester5Plus) {
        Write-Host "Executing tests with Pester 5.x..." -ForegroundColor Green
        $testResult = Invoke-Pester -Configuration $pesterConfig
    } else {
        Write-Host "Executing tests with Pester 3.x..." -ForegroundColor Yellow
        $testResult = Invoke-Pester @pesterParams
        
        # For Pester 3.x, manually save code coverage data if requested
        if ($Coverage -and $testResult.CodeCoverage) {
            try {
                $coverageOutputPath = Join-Path $TestResultsPath "coverage.xml"
                $testResult.CodeCoverage | Export-Clixml -Path $coverageOutputPath -Force
                Write-Host "Code coverage data saved to: $coverageOutputPath" -ForegroundColor Gray
            }
            catch {
                Write-Warning "Failed to save code coverage data: $_"
            }
        }
    }
    
    # Display results summary (handle version differences)
    Write-Host "`n=== Test Results Summary ===" -ForegroundColor Cyan
    
    if ($isPester5Plus) {
        Write-Host "Total Tests: $($testResult.TotalCount)" -ForegroundColor White
        Write-Host "Passed: $($testResult.PassedCount)" -ForegroundColor Green
        Write-Host "Failed: $($testResult.FailedCount)" -ForegroundColor Red
        Write-Host "Skipped: $($testResult.SkippedCount)" -ForegroundColor Yellow
        Write-Host "Duration: $($testResult.Duration)" -ForegroundColor Gray
    } else {
        # Pester 3.x has different property names
        Write-Host "Total Tests: $($testResult.TotalCount)" -ForegroundColor White
        Write-Host "Passed: $($testResult.PassedCount)" -ForegroundColor Green
        Write-Host "Failed: $($testResult.FailedCount)" -ForegroundColor Red
        Write-Host "Skipped: $($testResult.SkippedCount)" -ForegroundColor Yellow
        Write-Host "Duration: $($testResult.Time)" -ForegroundColor Gray
    }
    
    # Code coverage summary (handle version differences)
    if ($Coverage -and $testResult.CodeCoverage) {
        Write-Host "`n=== Code Coverage Summary ===" -ForegroundColor Cyan
        
        if ($isPester5Plus) {
            $coveragePercent = [math]::Round(($testResult.CodeCoverage.CoveragePercent), 2)
            Write-Host "Coverage: $coveragePercent%" -ForegroundColor $(if ($coveragePercent -ge 80) { 'Green' } elseif ($coveragePercent -ge 60) { 'Yellow' } else { 'Red' })
            Write-Host "Lines Analyzed: $($testResult.CodeCoverage.AnalyzedFiles.Count)" -ForegroundColor Gray
            Write-Host "Lines Covered: $($testResult.CodeCoverage.HitCount)" -ForegroundColor Gray
            Write-Host "Lines Missed: $($testResult.CodeCoverage.MissedCount)" -ForegroundColor Gray
            
            # Show missed commands if any
            if ($testResult.CodeCoverage.MissedCommands.Count -gt 0 -and -not $CI) {
                Write-Host "`nMissed Commands:" -ForegroundColor Yellow
                $testResult.CodeCoverage.MissedCommands | ForEach-Object {
                    Write-Host "  $($_.File):$($_.Line) - $($_.Function)" -ForegroundColor Red
                }
            }
        } else {
            # Pester 3.x code coverage properties
            $hitLines = $testResult.CodeCoverage.HitCommands.Count
            $missedLines = $testResult.CodeCoverage.MissedCommands.Count
            $totalLines = $hitLines + $missedLines
            $coveragePercent = if ($totalLines -gt 0) { [math]::Round(($hitLines / $totalLines) * 100, 2) } else { 0 }
            
            Write-Host "Coverage: $coveragePercent%" -ForegroundColor $(if ($coveragePercent -ge 80) { 'Green' } elseif ($coveragePercent -ge 60) { 'Yellow' } else { 'Red' })
            Write-Host "Lines Analyzed: $($testResult.CodeCoverage.AnalyzedFiles.Count)" -ForegroundColor Gray
            Write-Host "Lines Covered: $hitLines" -ForegroundColor Gray
            Write-Host "Lines Missed: $missedLines" -ForegroundColor Gray
            
            # Show missed commands if any
            if ($testResult.CodeCoverage.MissedCommands.Count -gt 0 -and -not $CI) {
                Write-Host "`nMissed Commands:" -ForegroundColor Yellow
                $testResult.CodeCoverage.MissedCommands | ForEach-Object {
                    Write-Host "  $($_.File):$($_.Line) - $($_.Function)" -ForegroundColor Red
                }
            }
        }
    }
    
    # Output file locations
    Write-Host "`n=== Output Files ===" -ForegroundColor Cyan
    
    if ($isPester5Plus) {
        Write-Host "Test Results: $($pesterConfig.TestResult.OutputPath)" -ForegroundColor Gray
        if ($Coverage) {
            Write-Host "Coverage Report: $($pesterConfig.CodeCoverage.OutputPath)" -ForegroundColor Gray
        }
    } else {
        Write-Host "Test Results: $($pesterParams.OutputFile)" -ForegroundColor Gray
        if ($Coverage) {
            $coverageOutputPath = Join-Path $TestResultsPath "coverage.xml"
            Write-Host "Coverage Report: $coverageOutputPath (PowerShell CliXml format)" -ForegroundColor Gray
        }
    }
    
    # Exit with appropriate code
    $exitCode = if ($testResult.FailedCount -eq 0) { 0 } else { 1 }
    
    if ($exitCode -eq 0) {
        Write-Host "`nAll tests passed successfully!" -ForegroundColor Green
    } else {
        Write-Host "`nSome tests failed. Check the results above." -ForegroundColor Red
    }
    
    # In CI mode, fail the build if tests fail
    if ($CI -and $exitCode -ne 0) {
        throw "Test execution failed with $($testResult.FailedCount) failed tests"
    }
    
    return $exitCode
}
catch {
    Write-Error "Test execution failed: $_"
    return 1
}
finally {
    Pop-Location
}