#
# Module manifest for module 'ConfigureWSL'
#

@{

# Script module or binary module file associated with this manifest.
RootModule = 'ConfigureWSL.psm1'

# Version number of this module.
ModuleVersion = '2.1.0'

# Supported PSEditions
CompatiblePSEditions = @('Desktop', 'Core')

# ID used to uniquely identify this module
GUID = '12345678-1234-1234-1234-123456789012'

# Author of this module
Author = 'WSL Configuration Team'

# Company or vendor of this module
CompanyName = 'Unknown'

# Copyright statement for this module
Copyright = '(c) WSL Configuration Team. All rights reserved.'

# Description of the functionality provided by this module
Description = 'PowerShell module for configuring WSL development environments with Ubuntu, FiraCode Nerd Font, and Starship prompt'

# Minimum version of the PowerShell engine required by this module
PowerShellVersion = '5.1'

# Name of the PowerShell host required by this module
# PowerShellHostName = ''

# Minimum version of the PowerShell host required by this module
# PowerShellHostVersion = ''

# Minimum version of Microsoft .NET Framework required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
# DotNetFrameworkVersion = ''

# Minimum version of the common language runtime (CLR) required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
# ClrVersion = ''

# Processor architecture (None, X86, Amd64) required by this module
# ProcessorArchitecture = ''

# Modules that must be imported into the global environment prior to importing this module
# RequiredModules = @()

# Assemblies that must be loaded prior to importing this module
# RequiredAssemblies = @()

# Script files (.ps1) that are run in the caller's environment prior to importing this module.
# ScriptsToProcess = @()

# Type files (.ps1xml) to be loaded when importing this module
# TypesToProcess = @()

# Format files (.ps1xml) to be loaded when importing this module
# FormatsToProcess = @()

# Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
# NestedModules = @()

# Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
FunctionsToExport = @(
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

# Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
CmdletsToExport = @()

# Variables to export from this module
VariablesToExport = '*'

# Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
AliasesToExport = @()

# DSC resources to export from this module
# DscResourcesToExport = @()

# List of all modules packaged with this module
# ModuleList = @()

# List of all files packaged with this module
# FileList = @()

# Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
PrivateData = @{

    PSData = @{

        # Tags applied to this module. These help with module discovery in online galleries.
        Tags = @('WSL', 'Ubuntu', 'Development', 'Configuration', 'Starship', 'FiraCode', 'Windows', 'Linux')

        # A URL to the license for this module.
        LicenseUri = 'https://github.com/yourusername/configure-wsl/blob/main/LICENSE'

        # A URL to the main website for this project.
        ProjectUri = 'https://github.com/yourusername/configure-wsl'

        # A URL to an icon representing this module.
        # IconUri = ''

        # ReleaseNotes of this module
        ReleaseNotes = @'
## 2.1.0
- Enhanced WSL distribution state checking with stuck operation detection
- Improved error handling with specific WSL error code translations
- Silent font installation using Windows API (no more prompts)
- Starship installation now uses user directory to avoid sudo prompts
- Fixed VS Code configuration updates for PSCustomObject handling
- Added comprehensive unit tests for new functions
- Automatic retry mechanism for failed WSL installations

## 2.0.0
- Complete rewrite with proper module structure
- Added comprehensive unit testing with Pester
- Implemented CI/CD with GitHub Actions
- Enhanced error handling and logging
- Added backup and restore functionality
- Improved WSL installation detection and handling
'@

        # Prerelease string of this module
        # Prerelease = ''

        # Flag to indicate whether the module requires explicit user acceptance for install/update/save
        # RequireLicenseAcceptance = $false

        # External dependent modules of this module
        # ExternalModuleDependencies = @()

    } # End of PSData hashtable

} # End of PrivateData hashtable

# HelpInfo URI of this module
# HelpInfoURI = ''

# Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
# DefaultCommandPrefix = ''

}