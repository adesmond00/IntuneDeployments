﻿# This script installs the 'TestApp' application along with its dependencies.
# Generated on: 01/02/2025 15:48:23

param()

# Initialize variables
$logFolder = "C:\sigmatech\installLogs"
$mainInstaller = "C:\Users\Avi\Documents\Projects\Intune Deployments Files\Current working folder\Intune Deployments\EXE Deployment\Apps\TestApp\source\test.exe"
$depFolder = "C:\Users\Avi\Documents\Projects\Intune Deployments Files\Current working folder\Intune Deployments\EXE Deployment\Apps\TestApp\source\Dependencies"
$installArgs = "/S"
$uninstallArgs = "/S /uninstall"

# Create log folder if it doesn't exist
if (!(Test-Path $logFolder)) {
    New-Item -ItemType Directory -Path $logFolder | Out-Null
}

# Remove logs older than 30 days
Get-ChildItem -Path $logFolder -Filter *.log -Recurse -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) } |
    Remove-Item -Force -ErrorAction SilentlyContinue

# Install dependencies
if (Test-Path $depFolder) {
    $dependencies = Get-ChildItem -Path $depFolder -Filter *.exe -File -ErrorAction SilentlyContinue
    if ($dependencies) {
        foreach ($dep in $dependencies) {
            $depLog = Join-Path $logFolder ("Install_" + $($dep.BaseName) + ".log")
            Write-Host "Installing dependency: $($dep.Name)"
            Start-Process -FilePath "$($dep.FullName)" -ArgumentList $installArgs -Wait -NoNewWindow -RedirectStandardOutput "$depLog" -RedirectStandardError "$depLog"
        }
    }
}

# Install main application
$mainLog = Join-Path $logFolder ("Install_" + $([System.IO.Path]::GetFileNameWithoutExtension($mainInstaller)) + ".log")
Write-Host "Installing main application EXE: $([System.IO.Path]::GetFileName($mainInstaller))"
Start-Process -FilePath $mainInstaller -ArgumentList $installArgs -Wait -NoNewWindow -RedirectStandardOutput "$mainLog" -RedirectStandardError "$mainLog"

Write-Host "Installation of 'TestApp' complete."
