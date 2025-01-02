# This script uninstalls the 'TestApp' application along with its dependencies.
# Generated on: 01/02/2025 16:09:54

param()

# Initialize variables
$logFolder = "C:\sigmatech\installLogs"
$mainInstaller = "C:\Users\Avi\Documents\Projects\Intune Deployments Files\Current working folder\Intune Deployments\EXE Deployment\Apps\TestApp\source\test.exe"
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

# Uninstall main application
$mainLog = Join-Path $logFolder ("Uninstall_" + $([System.IO.Path]::GetFileNameWithoutExtension($mainInstaller)) + ".log")
Write-Host "Uninstalling main application EXE: $([System.IO.Path]::GetFileName($mainInstaller))"
Start-Process -FilePath $mainInstaller -ArgumentList $uninstallArgs -Wait -NoNewWindow -RedirectStandardOutput "$mainLog" -RedirectStandardError "$mainLog"

Write-Host "Uninstallation of 'TestApp' complete."
