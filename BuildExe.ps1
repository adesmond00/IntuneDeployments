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
     - Creates C:\sigmatech\installLogs if it doesn't exist.
     - Installs each dependency silently, one by one, logging to file (if dependencies exist).
     - Installs the main EXE silently, logging to file.
     - Cleans up any logs older than 30 days in C:\sigmatech\installLogs.
  4. Generates an uninstall.ps1 script that:
     - Creates C:\sigmatech\installLogs if it doesn't exist.
     - Uninstalls the main EXE silently, logging to file.
     - Uninstalls each dependency silently, logging to file (if dependencies exist).
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

# Get the EXE deployment root relative to the script location
$EXEDeploymentRoot = Join-Path $PSScriptRoot "EXE Deployment"

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

# Get all subfolders in the EXE Deployment/Apps directory (each is an 'app')
$appsFolder = Join-Path $EXEDeploymentRoot "Apps"
$appFolders = Get-ChildItem -Path $appsFolder -Directory -ErrorAction SilentlyContinue

foreach ($appFolder in $appFolders) {
    $appName = $appFolder.Name
    Write-Host "Processing application: $appName"
    
    # Create source and output folders if they don't exist
    $sourceFolder = Join-Path $appFolder.FullName "source"
    $outputFolder = Join-Path $appFolder.FullName "output"
    
    if (-not (Test-Path $sourceFolder)) {
        New-Item -ItemType Directory -Path $sourceFolder | Out-Null
        Write-Host "Created source folder at: $sourceFolder"
    }
    
    if (-not (Test-Path $outputFolder)) {
        New-Item -ItemType Directory -Path $outputFolder | Out-Null
        Write-Host "Created output folder at: $outputFolder"
    }

    # Create Dependencies folder if it doesn't exist
    $depFolder = Join-Path $sourceFolder "Dependencies"
    if (-not (Test-Path $depFolder)) {
        New-Item -ItemType Directory -Path $depFolder | Out-Null
        Write-Host "Created Dependencies folder at: $depFolder"
    }

    # Move any .exe files from app folder root to source folder
    $exeFiles = Get-ChildItem -Path $appFolder.FullName -Filter *.exe -File -Depth 0 -ErrorAction SilentlyContinue
    foreach ($exe in $exeFiles) {
        # Only move if not already in source folder
        if ($exe.DirectoryName -ne $sourceFolder) {
            $destination = Join-Path $sourceFolder $exe.Name
            Move-Item -Path $exe.FullName -Destination $destination -Force
            Write-Host "Moved $($exe.Name) to $destination"
        }
    }

    # Verify folder structure
    if (-not (Test-Path $sourceFolder)) {
        Write-Error "Failed to create source folder at: $sourceFolder"
        continue
    }
    if (-not (Test-Path $depFolder)) {
        Write-Error "Failed to create Dependencies folder at: $depFolder"
        continue
    }

    # Move any .exe files from app folder to source folder
    $exeFiles = Get-ChildItem -Path $appFolder.FullName -Filter *.exe -File -Recurse -ErrorAction SilentlyContinue
    foreach ($exe in $exeFiles) {
        # Only move if not already in source folder
        if ($exe.DirectoryName -ne $sourceFolder) {
            $destination = Join-Path $sourceFolder $exe.Name
            Move-Item -Path $exe.FullName -Destination $destination -Force
            Write-Host "Moved $($exe.Name) to $destination"
        }
    }

    # Identify the primary installer .exe (assume there is exactly one)
    $mainInstaller = Get-ChildItem -Path $sourceFolder -Filter *.exe -File -ErrorAction SilentlyContinue |
                     Where-Object { $_.DirectoryName -eq $sourceFolder } |
                     Select-Object -First 1

    if (-not $mainInstaller) {
        Write-Warning "No .exe found in $sourceFolder. Skipping."
        continue
    }

    # Define variables for the generated scripts
    $scriptVars = @"
`$logFolder = "C:\sigmatech\installLogs"
`$mainInstaller = "$($mainInstaller.FullName)"
`$depFolder = "$depFolder"
`$installArgs = "$joinedInstallArgs"
`$uninstallArgs = "$joinedUninstallArgs"
"@

    # Build the install.ps1 script content
    $installScript = @"
# This script installs the '$appName' application along with its dependencies.
# Generated on: $(Get-Date)

param()

# Initialize variables
$scriptVars

# Create log folder if it doesn't exist
if (!(Test-Path `$logFolder)) {
    New-Item -ItemType Directory -Path `$logFolder | Out-Null
}

# Remove logs older than $logRetentionDays days
Get-ChildItem -Path `$logFolder -Filter *.log -Recurse -ErrorAction SilentlyContinue |
    Where-Object { `$_.LastWriteTime -lt (Get-Date).AddDays(-$logRetentionDays) } |
    Remove-Item -Force -ErrorAction SilentlyContinue

# Install dependencies
if (Test-Path `$depFolder) {
    `$dependencies = Get-ChildItem -Path `$depFolder -Filter *.exe -File -ErrorAction SilentlyContinue
    if (`$dependencies) {
        foreach (`$dep in `$dependencies) {
            `$depLog = Join-Path `$logFolder ("Install_" + `$(`$dep.BaseName) + ".log")
            Write-Host "Installing dependency: `$(`$dep.Name)"
            Start-Process -FilePath "`$(`$dep.FullName)" -ArgumentList `$installArgs -Wait -NoNewWindow -RedirectStandardOutput "`$depLog" -RedirectStandardError "`$depLog"
        }
    }
}

# Install main application
`$mainLog = Join-Path `$logFolder ("Install_" + `$([System.IO.Path]::GetFileNameWithoutExtension(`$mainInstaller)) + ".log")
Write-Host "Installing main application EXE: `$([System.IO.Path]::GetFileName(`$mainInstaller))"
Start-Process -FilePath `$mainInstaller -ArgumentList `$installArgs -Wait -NoNewWindow -RedirectStandardOutput "`$mainLog" -RedirectStandardError "`$mainLog"

Write-Host "Installation of '$appName' complete."
"@

    # Build the uninstall.ps1 script content
    $uninstallScript = @"
# This script uninstalls the '$appName' application along with its dependencies.
# Generated on: $(Get-Date)

param()

# Initialize variables
$scriptVars

# Create log folder if it doesn't exist
if (!(Test-Path `$logFolder)) {
    New-Item -ItemType Directory -Path `$logFolder | Out-Null
}

# Remove logs older than $logRetentionDays days
Get-ChildItem -Path `$logFolder -Filter *.log -Recurse -ErrorAction SilentlyContinue |
    Where-Object { `$_.LastWriteTime -lt (Get-Date).AddDays(-$logRetentionDays) } |
    Remove-Item -Force -ErrorAction SilentlyContinue

# Uninstall main application
`$mainLog = Join-Path `$logFolder ("Uninstall_" + `$([System.IO.Path]::GetFileNameWithoutExtension(`$mainInstaller)) + ".log")
Write-Host "Uninstalling main application EXE: `$([System.IO.Path]::GetFileName(`$mainInstaller))"
Start-Process -FilePath `$mainInstaller -ArgumentList `$uninstallArgs -Wait -NoNewWindow -RedirectStandardOutput "`$mainLog" -RedirectStandardError "`$mainLog"

# Uninstall dependencies
if (Test-Path `$depFolder) {
    `$dependencies = Get-ChildItem -Path `$depFolder -Filter *.exe -File -ErrorAction SilentlyContinue
    if (`$dependencies) {
        foreach (`$dep in `$dependencies) {
            `$depLog = Join-Path `$logFolder ("Uninstall_" + `$(`$dep.BaseName) + ".log")
            Write-Host "Uninstalling dependency: `$(`$dep.Name)"
            Start-Process -FilePath "`$(`$dep.FullName)" -ArgumentList `$uninstallArgs -Wait -NoNewWindow -RedirectStandardOutput "`$depLog" -RedirectStandardError "`$depLog"
        }
    }
}

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
