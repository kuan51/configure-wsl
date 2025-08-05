@{
    # Pester Configuration for ConfigureWSL Module Tests
    
    # Test Discovery
    Path = @(
        './tests/*.Tests.ps1'
    )
    
    # Execution Configuration
    PassThru = $true
    
    # Output Configuration
    Output = @{
        Verbosity = 'Detailed'
        StackTraceVerbosity = 'Filtered'
        CIFormat = 'Auto'
    }
    
    # Code Coverage Configuration
    CodeCoverage = @{
        Enabled = $true
        Path = @(
            './src/*.psm1',
            './src/*.ps1'
        )
        OutputFormat = 'JaCoCo'
        OutputPath = './tests/coverage.xml'
        OutputEncoding = 'UTF8'
        UseBreakpoints = $false
        SingleHitBreakpoints = $true
    }
    
    # Test Result Configuration
    TestResult = @{
        Enabled = $true
        OutputFormat = 'NUnitXml'
        OutputPath = './tests/test-results.xml'
        OutputEncoding = 'UTF8'
        TestSuiteName = 'ConfigureWSL'
    }
    
    # Run Configuration
    Run = @{
        PassThru = $true
        Path = @(
            './tests/*.Tests.ps1'
        )
        ExcludePath = @()
        ScriptBlock = @()
        Container = @()
        TestExtension = '.Tests.ps1'
        Exit = $false
        Throw = $false
        SkipRemainingOnFailure = 'None'
    }
    
    # Filter Configuration
    Filter = @{
        Tag = @()
        ExcludeTag = @()
        Line = @()
        ExcludeLine = @()
        FullName = @()
    }
    
    # Should Configuration
    Should = @{
        ErrorAction = 'Stop'
        StackTraceVerbosity = 'Filtered'
    }
    
    # Debug Configuration
    Debug = @{
        ShowFullErrors = $false
        WriteDebugMessages = $false
        WriteDebugMessagesFrom = @()
        ShowNavigationMarkers = $false
        ReturnRawResultObject = $false
    }
}