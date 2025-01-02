param (
    [string]$appName
)

# Clone Microsoft Win32 Content Prep Tool
$contentPrepPath = "$PSScriptRoot\Microsoft-Win32-Content-Prep-Tool"
if (-Not (Test-Path $contentPrepPath)) {
    git clone https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool.git $contentPrepPath
}

# Get all apps in MSI Deployment\Apps
$appsPath = "$PSScriptRoot\MSI Deployment\Apps"

if ($appName) {
    # Process specific app
    $appPath = "$appsPath\$appName"
    if (-Not (Test-Path $appPath)) {
        Write-Error "App '$appName' not found in $appsPath"
        exit 1
    }
    $apps = @(Get-Item -Path $appPath)
} else {
    # Process all apps
    $apps = Get-ChildItem -Path $appsPath -Directory
}

foreach ($app in $apps) {
    $appName = $app.Name
    $sourceFolder = "$appsPath\$appName\source"
    $setupFile = "$sourceFolder\install.ps1"
    $outputFolder = "$appsPath\$appName\output"
    
    if (Test-Path $setupFile) {
        Write-Host "Processing $appName..."
        
        # Run Content Prep Tool
        & "$contentPrepPath\IntuneWinAppUtil.exe" -c $sourceFolder -s $setupFile -o $outputFolder
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "$appName processed successfully"
        } else {
            Write-Error "Failed to process $appName"
        }
    } else {
        Write-Warning "Skipping $appName - install.ps1 not found in source folder"
    }
}
