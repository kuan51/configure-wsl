# 🚀 Configure WSL - Windows Subsystem for Linux Setup Automation

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue.svg)](https://github.com/PowerShell/PowerShell)
[![Windows](https://img.shields.io/badge/Windows-10%2B-0078D6.svg)](https://www.microsoft.com/windows)
[![WSL](https://img.shields.io/badge/WSL-2-FCC624.svg)](https://docs.microsoft.com/en-us/windows/wsl/)

A PowerShell script that automatically sets up a fully configured WSL development environment with Ubuntu, Starship prompt, and FiraCode Nerd Font for an optimal coding experience in Windows Terminal and VS Code.

## ✨ Features

- 🐧 **Automated WSL & Ubuntu Installation** - Handles the complete WSL setup process
- 🌟 **Starship Prompt** - Beautiful, minimal, and fast cross-shell prompt
- 🔤 **FiraCode Nerd Font** - Programming ligatures and icon support
- 🖥️ **Windows Terminal Configuration** - Auto-configures font settings
- 📝 **VS Code Integration** - Sets up font preferences automatically
- 📊 **Comprehensive Logging** - Track every step of the installation
- 💾 **Automatic Backups** - Backs up configuration files before modification
- 🛡️ **Error Handling** - Robust error handling with recovery options

## 🚀 Quick Start

1. **Open PowerShell as Administrator**
   ```powershell
   # Right-click on PowerShell and select "Run as Administrator"
   ```

2. **Run the script with default settings**
   ```powershell
   .\configure-wsl.ps1
   ```

That's it! The script will handle everything else.

## 📋 Prerequisites

- Windows 10 version 2004 (build 19041) or later for WSL2
- PowerShell 5.1 or later
- Administrator privileges
- Internet connection for downloads

## 🎯 What Gets Installed

1. **WSL2 with Ubuntu** (default distribution)
2. **Starship Prompt** with bash/zsh integration
3. **FiraCode Nerd Font** for programming ligatures
4. **Automatic configuration** for:
   - Windows Terminal
   - Visual Studio Code
   - WSL shell environments

## 💻 Usage Examples

### Basic Installation
```powershell
# Install with all default settings
.\configure-wsl.ps1
```

### Custom Distribution
```powershell
# Install Ubuntu 22.04 instead of default Ubuntu
.\configure-wsl.ps1 -DistroName "Ubuntu-22.04"
```

### Skip Font Installation
```powershell
# Skip FiraCode font if you already have it
.\configure-wsl.ps1 -SkipFontInstall
```

### Skip Starship Installation
```powershell
# Skip Starship if you prefer another prompt
.\configure-wsl.ps1 -SkipStarship
```

### Custom Log Location
```powershell
# Specify custom log file path
.\configure-wsl.ps1 -LogPath "C:\Logs\wsl-setup.log"
```

### Combined Options
```powershell
# Use multiple parameters together
.\configure-wsl.ps1 -DistroName "Ubuntu-22.04" -SkipFontInstall -LogPath "C:\MyLogs\wsl.log"
```

## 📖 Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-DistroName` | String | `"Ubuntu"` | WSL distribution to install |
| `-SkipFontInstall` | Switch | `$false` | Skip FiraCode Nerd Font installation |
| `-SkipStarship` | Switch | `$false` | Skip Starship prompt installation |
| `-LogPath` | String | `"%TEMP%\configure-wsl.log"` | Custom log file location |

## 🔍 What Happens During Installation

1. **System Check**
   - Verifies Windows version compatibility
   - Checks for administrator privileges
   - Tests internet connectivity

2. **WSL Setup**
   - Enables WSL feature if not present
   - Installs chosen Linux distribution
   - Prompts for initial user setup

3. **Font Installation**
   - Downloads FiraCode Nerd Font
   - Installs font system-wide
   - Cleans up temporary files

4. **Starship Configuration**
   - Installs Starship in WSL
   - Configures shell integration (.bashrc/.zshrc)
   - Sets up dependencies

5. **Application Configuration**
   - Updates Windows Terminal settings
   - Configures VS Code font preferences
   - Creates backups of all modified files

## 🛠️ Troubleshooting

### WSL Installation Issues
If WSL fails to install automatically:
```powershell
# Manual WSL installation
wsl --install
# Restart your computer, then run the script again
```

### Font Not Showing
- Restart Windows Terminal and VS Code after installation
- Check if "FiraCode Nerd Font" appears in your font list
- Manually select the font in application settings if needed

### Permission Errors
Ensure you're running PowerShell as Administrator:
```powershell
# Check if running as admin
([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
```

### View Installation Logs
```powershell
# Default log location
notepad "$env:TEMP\configure-wsl.log"
```

## 📁 File Locations

- **Logs**: `%TEMP%\configure-wsl.log` (default)
- **Backups**: `%TEMP%\wsl-config-backups-[timestamp]\`
- **Windows Terminal Settings**: `%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_*\LocalState\settings.json`
- **VS Code Settings**: `%APPDATA%\Code\User\settings.json`

## 🔄 Post-Installation Steps

1. **Restart Applications**
   - Close and reopen Windows Terminal
   - Restart VS Code/Cursor

2. **Verify Installation**
   ```bash
   # In WSL, check Starship
   starship --version
   
   # Check if prompt is active
   echo $PROMPT_COMMAND
   ```

3. **Customize Starship** (optional)
   ```bash
   # Create Starship config
   mkdir -p ~/.config && touch ~/.config/starship.toml
   ```

## 🤝 Contributing

Feel free to submit issues, fork the repository, and create pull requests for any improvements.

## 📄 License

This project is open source and available under the [MIT License](LICENSE).

## 🙏 Acknowledgments

- [Starship](https://starship.rs/) - The minimal, blazing-fast, and infinitely customizable prompt
- [Nerd Fonts](https://www.nerdfonts.com/) - Iconic font aggregator, collection, and patcher
- [Microsoft WSL](https://docs.microsoft.com/en-us/windows/wsl/) - Windows Subsystem for Linux documentation
