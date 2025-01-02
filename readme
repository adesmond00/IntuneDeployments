# Intune Deployment Automation

This repository contains PowerShell scripts for automating application deployments through Microsoft Intune, supporting both MSI and EXE package types.

## Directory Structure

```
Intune Deployments/
├── BuildExe.ps1          # EXE deployment script
├── BuildMsi.ps1          # MSI deployment script
├── BuildWinget.ps1       # Winget deployment script
├── main.ps1              # Main deployment controller
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
   .\main.ps1 -deploymentType MSI -appName [AppName]
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
   .\main.ps1 -deploymentType EXE
   ```
4. The script will:
   - Generate install.ps1 and uninstall.ps1 scripts
   - Handle dependency installation/uninstallation
   - Create log files in `C:\sigmatech\installLogs`

### General Deployment

To process both MSI and EXE deployments:
```powershell
.\main.ps1
```

## Configuration

### MSI Deployment Options
- `-appName`: Specify a specific application to process (optional)
- Default install/uninstall arguments: `/S`

### EXE Deployment Options
- `-InstallArgs`: Custom installation arguments (default: `/S`)
- `-UninstallArgs`: Custom uninstallation arguments (default: `/S /uninstall`)
- Log retention: 30 days

## Examples

Process all deployments:
```powershell
.\main.ps1
```

Deploy specific MSI application:
```powershell
.\main.ps1 -deploymentType MSI -appName "GoogleChrome"
```

Deploy EXE with custom arguments:
```powershell
.\main.ps1 -deploymentType EXE -InstallArgs "/quiet" -UninstallArgs "/uninstall /quiet"
```

## Notes
- Logs are stored in `C:\sigmatech\installLogs`
- Scripts are generated with execution policy bypass for silent operation
- Ensure proper folder structure before running deployments
