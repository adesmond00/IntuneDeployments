# Intune Deployment Automation

This repository contains standalone PowerShell scripts for automating application deployments through Microsoft Intune, supporting MSI, EXE, and Winget package types.

## Directory Structure

```
Intune Deployments/
├── BuildExe.ps1          # EXE deployment script
├── BuildMsi.ps1          # MSI deployment script
├── BuildWinget.ps1       # Winget deployment script
├── EXE Deployment/       # EXE application deployments
│   └── Apps/             # Individual EXE applications
├── MSI Deployment/       # MSI application deployments
│   └── Apps/             # Individual MSI applications
└── tools/                # Supporting tools
    ├── Detect-App/       # Application detection scripts
    ├── Get-MsiProductCode/ # MSI product code retrieval
    ├── Install-MSI/      # MSI installation scripts
    └── Uninstall-MSI/    # MSI uninstallation scripts
```

## Usage

### MSI Deployments

1. Place your MSI file in `MSI Deployment/Apps/[AppName]/`
2. Run the deployment script:
   ```powershell
   .\BuildMsi.ps1 -appName [AppName]
   ```
3. The script will:
   - Move the MSI file to the source directory
   - Generate install.ps1 and uninstall.ps1 scripts
   - Create a usage.txt file with deployment instructions

### EXE Deployments

1. Place your EXE file in `EXE Deployment/Apps/[AppName]/source/`
2. Add any dependencies in `EXE Deployment/Apps/[AppName]/source/Dependencies/`
3. Run the deployment script:
   ```powershell
   .\BuildExe.ps1
   ```
4. The script will:
   - Generate install.ps1 and uninstall.ps1 scripts
   - Handle dependency installation/uninstallation
   - Create log files in `C:\sigmatech\installLogs`

### Winget Deployments

1. Place your Winget package files in the appropriate directory
2. Run the deployment script:
   ```powershell
   .\BuildWinget.ps1
   ```

## Examples

# Example 1: Install Visual Studio Code (no scripts)
.\Install-Uninstall-WinGet.ps1 -WinGetID "Microsoft.VisualStudioCode" -Install

# Example 2: Install Git with a PreInstall and PostInstall script
.\Install-Uninstall-WinGet.ps1 `
    -WinGetID "Git.Git" `
    -Install `
    -PreInstallScript  "C:\Scripts\PreInstall.ps1" `
    -PostInstallScript "C:\Scripts\PostInstall.ps1"

# Example 3: Uninstall Visual Studio Code
.\Install-Uninstall-WinGet.ps1 -WinGetID "Microsoft.VisualStudioCode" -Uninstall

## Configuration

### MSI Deployment Options
- `-appName`: Specify a specific application to process (optional)
- `-InstallParams`: Custom installation parameters (default: "/quiet /norestart")
- Default install/uninstall arguments: `/S`

### EXE Deployment Options
- `-InstallArgs`: Custom installation arguments (default: `/S`)
- `-UninstallArgs`: Custom uninstallation arguments (default: `/S /uninstall`)
- Log retention: 30 days

## Examples

Deploy specific MSI application:
```powershell
.\BuildMsi.ps1 -appName "GoogleChrome"
```

Deploy EXE with custom arguments:
```powershell
.\BuildExe.ps1 -InstallArgs "/quiet" -UninstallArgs "/uninstall /quiet"
```

## Notes
- Logs are stored in `C:\sigmatech\installLogs`
- Scripts are generated with execution policy bypass for silent operation
- Ensure proper folder structure before running deployments
