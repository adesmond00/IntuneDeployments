# BuildMsi.ps1 - Handles MSI deployment logic

param (
    [string]$appName
)

# If no specific app is provided, process all apps
if ([string]::IsNullOrEmpty($appName)) {
    $appNames = Get-ChildItem -Path "MSI Deployment\Apps" -Directory | Select-Object -ExpandProperty Name
} else {
    $appNames = @($appName)
}

foreach ($currentApp in $appNames) {
    # Define paths
    $appPath = Join-Path "MSI Deployment\Apps" $currentApp
    $sourcePath = Join-Path $appPath "source"
    $outputPath = Join-Path $appPath "output"

    # Create source and output directories if they don't exist
    try {
        if (-not (Test-Path $sourcePath)) {
            Write-Host "Creating source directory: $sourcePath"
            New-Item -ItemType Directory -Path $sourcePath | Out-Null
        } else {
            Write-Host "Source directory exists: $sourcePath"
            # Remove only deployment files if they exist
            Remove-Item -Path (Join-Path $sourcePath "install.ps1") -ErrorAction SilentlyContinue
            Remove-Item -Path (Join-Path $sourcePath "uninstall.ps1") -ErrorAction SilentlyContinue
            Remove-Item -Path (Join-Path $sourcePath "usage.txt") -ErrorAction SilentlyContinue
        }
        
        if (-not (Test-Path $outputPath)) {
            Write-Host "Creating output directory: $outputPath"
            New-Item -ItemType Directory -Path $outputPath | Out-Null
        } else {
            Write-Host "Output directory exists: $outputPath"
        }
    }
    catch {
        Write-Error "Failed to create required directories: $_"
        continue
    }

    # Move .msi file to source directory
    $msiFile = Get-ChildItem -Path $appPath -Filter *.msi | Select-Object -First 1
    if ($msiFile) {
        Move-Item -Path $msiFile.FullName -Destination $sourcePath -Force
    }

    # Get MSI file path
    $msiFile = Get-ChildItem -Path $sourcePath -Filter *.msi | Select-Object -First 1
    if (-not $msiFile) {
        Write-Error "No MSI file found in source directory: $sourcePath"
        continue
    }
    $msiPath = $msiFile.FullName
    
    # Verify MSI file exists and is accessible
    if (-not (Test-Path $msiPath)) {
        Write-Error "MSI file not found at path: $msiPath"
        continue
    }

    try {
        $productCode = & "${PSScriptRoot}\tools\Get-MsiProductCode\Get-MsiProductCode.ps1" -MsiPath $msiPath
        if (-not $productCode) {
            throw "Failed to retrieve product code from MSI file"
        }
        Write-Host "Successfully retrieved product code for ${currentApp}: ${productCode}"
    }
    catch {
        Write-Error "Error getting product code for ${currentApp}: ${_}"
        continue
    }

    # Create uninstall script
    $uninstallScriptPath = "${PSScriptRoot}\tools\Uninstall-MSI\Uninstall-MSI.ps1"
    if (Test-Path $uninstallScriptPath) {
        $uninstallScript = Get-Content $uninstallScriptPath -Raw
        Write-Host "Original uninstall script: $uninstallScript"
        Write-Host "Product code to insert: $productCode"
        $uninstallScript = $uninstallScript -replace '\{YOUR-PRODUCT-CODE-HERE\}', $productCode
        Write-Host "Modified uninstall script: $uninstallScript"
        Set-Content -Path (Join-Path $sourcePath "uninstall.ps1") -Value $uninstallScript
    } else {
        Write-Error "Uninstall-MSI tool not found at path: $uninstallScriptPath"
    }

    # Create install script
    $installScriptPath = "${PSScriptRoot}\tools\Install-MSI\Install-MSI.ps1"
    if (Test-Path $installScriptPath) {
        $installScript = Get-Content $installScriptPath -Raw
        $installScript = $installScript -replace 'path_to_file\.msi', ".\$($msiFile.Name)"
        Set-Content -Path (Join-Path $sourcePath "install.ps1") -Value $installScript
    } else {
        Write-Error "Install-MSI tool not found at path: $installScriptPath"
    }

    # Create usage.txt
    $usageContent = @(
        "Installation Usage: powershell.exe -executionpolicy bypass -windowstyle hidden -file .\install.ps1",
        "Uninstall Usage: powershell.exe -executionpolicy bypass -windowstyle hidden -file .\uninstall.ps1"
    )
    Set-Content -Path (Join-Path $sourcePath "usage.txt") -Value $usageContent
}
