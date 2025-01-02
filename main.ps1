# main.ps1 - Controls deployment logic

param (
    [string]$deploymentType,
    [string]$appName,
    [string[]]$InstallArgs = @("/S"),
    [string[]]$UninstallArgs = @("/S", "/uninstall")
)

# If deployment type not specified, process both
if ([string]::IsNullOrEmpty($deploymentType)) {
    $processMSI = $true
    $processEXE = $true
} else {
    # Validate deployment type
    if ($deploymentType -notin @("MSI", "EXE")) {
        Write-Error "Invalid deployment type. Must be 'MSI' or 'EXE'"
        exit 1
    }
    $processMSI = $deploymentType -eq "MSI"
    $processEXE = $deploymentType -eq "EXE"
}

# Check for MSI deployments
if ($processMSI) {
    $msiApps = Get-ChildItem -Path "MSI Deployment\Apps" -Directory
    if ($msiApps.Count -eq 0) {
        Write-Warning "No MSI applications found in MSI Deployment\Apps"
        $processMSI = $false
    }
}

# Check for EXE deployments
if ($processEXE) {
    $exeApps = Get-ChildItem -Path "EXE Deployment" -Directory
    if ($exeApps.Count -eq 0) {
        Write-Warning "No EXE applications found in EXE Deployment"
        $processEXE = $false
    }
}

# Start jobs for processing
$jobs = @()

if ($processMSI) {
    $msiJob = Start-Job -ScriptBlock {
        param($scriptRoot, $appName)
        & "$scriptRoot\BuildMsi.ps1" -appName $appName
    } -ArgumentList $PSScriptRoot, $appName
    $jobs += $msiJob
    Write-Host "Started MSI deployment processing..."
}

if ($processEXE) {
    $exeJob = Start-Job -ScriptBlock {
        param($scriptRoot, $InstallArgs, $UninstallArgs)
        & "$scriptRoot\BuildExe.ps1" -InstallArgs $InstallArgs -UninstallArgs $UninstallArgs
    } -ArgumentList $PSScriptRoot, $InstallArgs, $UninstallArgs
    $jobs += $exeJob
    Write-Host "Started EXE deployment processing..."
}

# Wait for jobs to complete and get results
if ($jobs.Count -gt 0) {
    $jobs | Wait-Job | Receive-Job
    $jobs | Remove-Job
}

Write-Host "Deployment processing complete."
