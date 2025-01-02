<#
.SYNOPSIS
  This script will auto-generate install.ps1 and uninstall.ps1 for each application
  found in the "EXE Deployment" folder, handling dependencies, logging, and cleanup of old logs.

.DESCRIPTION
  1. Scans each subfolder (application) in the EXE Deployment directory.
  2. Within each subfolder, looks for:
     - A "source" folder containing the main installer .exe.
     - A "Dependencies" folder containing zero or more .exe dependencies.
  3. Generates an install.ps1 script that:
     - Creates C:\sigmatech\installLogs if it doesn’t exist.
     - Installs each dependency silently, one by one, logging to file.
     - Installs the main EXE silently, logging to file.
     - Cleans up any logs older than 30 days in C:\sigmatech\installLogs.
  4. Generates an uninstall.ps1 script that:
     - Creates C:\sigmatech\installLogs if it doesn’t exist.
     - Uninstalls the main EXE silently, logging to file.
     - Uninstalls each dependency silently, logging to file.
     - Cleans up any logs older than 30 days in C:\sigmatech\installLogs.
  5. Places both scripts in the "source" folder for each application.

.PARAMETER InstallArgs
  One or more arguments for installing .exe files silently (e.g. "/S", "/quiet", etc.).

.PARAMETER UninstallArgs
  One or more arguments for uninstalling .exe files silently (e.g. "/S", "/uninstall", etc.).

.NOTES
  Author: Your Name
  Date:   2025-01-02
#>

param(
    [Parameter(Mandatory = $false)]
    [String[]]$InstallArgs = ("/S"),  # Default to /S if none specified

    [Parameter(Mandatory = $false)]
    [String[]]$UninstallArgs = ("/S", "/uninstall")  # Default to /S /uninstall if none specified
)

# -- Configuration --

# Change this path to the root folder where your EXE deployment folders live.
$EXEDeploymentRoot = "C:\Path\To\EXE Deployment"

# Convert array of args into a single string (e.g., "/S /silent")
$joinedInstallArgs   = $InstallArgs -join " "
$joinedUninstallArgs = $UninstallArgs -join " "

# Log folder
$logFolder = "C:\sigmatech\installLogs"

# Number of days to keep logs
$logRetentionDays = 30

# -- End Configuration --

Write-Host "Scanning for applications in '$EXEDeploymentRoot'..."
Write-Host "Using install arguments:   $joinedInstallArgs"
Write-Host "Using uninstall arguments: $joinedUninstallArgs"
Write-Host ""

# Get all subfolders in the EXE Deployment directory (each is an 'app')
$appFolders = Get-ChildItem -Path $EXEDeploymentRoot -Directory -ErrorAction SilentlyContinue

foreach ($appFolder in $appFolders) {
    $appName      = $appFolder.Name
    $sourceFolder = Join-Path $appFolder.FullName "source"
    $depFolder    = Join-Path $sourceFolder "Dependencies"

    # Skip if there's no "source" folder
    if (-not (Test-Path $sourceFolder)) {
        Write-Warning "Skipping '$($appFolder.FullName)' because no 'source' folder was found."
        continue
    }

    # Identify the primary installer .exe (assume there is exactly one)
    $mainInstaller = Get-ChildItem -Path $sourceFolder -Filter *.exe -File -ErrorAction SilentlyContinue |
                     Where-Object { $_.DirectoryName -eq $sourceFolder } |
                     Select-Object -First 1

    if (-not $mainInstaller) {
        Write-Warning "No .exe found in $sourceFolder. Skipping."
        continue
    }

    # Gather any dependency .exe files
    $dependencies = @()
    if (Test-Path $depFolder) {
        $dependencies = Get-ChildItem -Path $depFolder -Filter *.exe -File -ErrorAction SilentlyContinue
    }

    # Build the install.ps1 script content
    $installScript = @"
# This script installs the '$appName' application along with its dependencies.
# Generated on: $(Get-Date)

param()

# Create log folder if it doesn't exist
if (!(Test-Path "$logFolder")) {
    New-Item -ItemType Directory -Path "$logFolder" | Out-Null
}

# Remove logs older than $logRetentionDays days
Get-ChildItem -Path "$logFolder" -Filter *.log -Recurse -ErrorAction SilentlyContinue |
    Where-Object { \$_.LastWriteTime -lt (Get-Date).AddDays(-$logRetentionDays) } |
    Remove-Item -Force -ErrorAction SilentlyContinue

# Install dependencies
"@

    foreach ($dep in $dependencies) {
        $depLog = Join-Path $logFolder ("Install_" + $($dep.BaseName) + ".log")
        $installScript += @"
Write-Host "Installing dependency: $($dep.Name)"
Start-Process -FilePath "$($dep.FullName)" -ArgumentList "$joinedInstallArgs" -Wait -NoNewWindow -RedirectStandardOutput "$depLog" -RedirectStandardError "$depLog"
"@
    }

    # Now install the main EXE
    $mainLog = Join-Path $logFolder ("Install_" + $($mainInstaller.BaseName) + ".log")
    $installScript += @"
Write-Host "Installing main application EXE: $($mainInstaller.Name)"
Start-Process -FilePath "$($mainInstaller.FullName)" -ArgumentList "$joinedInstallArgs" -Wait -NoNewWindow -RedirectStandardOutput "$mainLog" -RedirectStandardError "$mainLog"
"@

    $installScript += @"
Write-Host "Installation of '$appName' complete."
"@

    # Build the uninstall.ps1 script content
    $uninstallScript = @"
# This script uninstalls the '$appName' application along with its dependencies.
# Generated on: $(Get-Date)

param()

# Create log folder if it doesn't exist
if (!(Test-Path "$logFolder")) {
    New-Item -ItemType Directory -Path "$logFolder" | Out-Null
}

# Remove logs older than $logRetentionDays days
Get-ChildItem -Path "$logFolder" -Filter *.log -Recurse -ErrorAction SilentlyContinue |
    Where-Object { \$_.LastWriteTime -lt (Get-Date).AddDays(-$logRetentionDays) } |
    Remove-Item -Force -ErrorAction SilentlyContinue

# Uninstall main application EXE
"@

    $uninstallMainLog = Join-Path $logFolder ("Uninstall_" + $($mainInstaller.BaseName) + ".log")
    $uninstallScript += @"
Write-Host "Uninstalling main application EXE: $($mainInstaller.Name)"
Start-Process -FilePath "$($mainInstaller.FullName)" -ArgumentList "$joinedUninstallArgs" -Wait -NoNewWindow -RedirectStandardOutput "$uninstallMainLog" -RedirectStandardError "$uninstallMainLog"
"@

    # Then uninstall dependencies (if applicable)
    foreach ($dep in $dependencies) {
        $unDepLog = Join-Path $logFolder ("Uninstall_" + $($dep.BaseName) + ".log")
        $uninstallScript += @"
Write-Host "Uninstalling dependency: $($dep.Name)"
Start-Process -FilePath "$($dep.FullName)" -ArgumentList "$joinedUninstallArgs" -Wait -NoNewWindow -RedirectStandardOutput "$unDepLog" -RedirectStandardError "$unDepLog"
"@
    }

    $uninstallScript += @"
Write-Host "Uninstallation of '$appName' complete."
"@

    # Write the scripts to the source folder
    $installScriptPath   = Join-Path $sourceFolder "install.ps1"
    $uninstallScriptPath = Join-Path $sourceFolder "uninstall.ps1"

    Write-Host "Generating install script at: $installScriptPath"
    $installScript | Set-Content -Path $installScriptPath -Encoding UTF8

    Write-Host "Generating uninstall script at: $uninstallScriptPath"
    $uninstallScript | Set-Content -Path $uninstallScriptPath -Encoding UTF8
}

Write-Host ""
Write-Host "Script generation complete."
