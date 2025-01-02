<#
.SYNOPSIS
    Installs or Uninstalls a WinGet package under System context with optional pre- and post-install scripts.

.DESCRIPTION
    This script demonstrates:
      - Locating winget.exe in the system,
      - Logging to a specific folder,
      - Handling optional pre- and post-install scripts (for the Install scenario),
      - Performing log cleanup of files older than 60 days,
      - Allowing either an Install or Uninstall operation via parameters.

.PARAMETER WinGetID
    The WinGet package identifier (e.g. "Microsoft.VisualStudioCode").

.PARAMETER Install
    Switch parameter to perform an INSTALL of the specified WinGet package.

.PARAMETER Uninstall
    Switch parameter to perform an UNINSTALL of the specified WinGet package.

.PARAMETER PreInstallScript
    Path to a pre-install script that should be run before the WinGet installation.
    This parameter is optional and only used during Install.

.PARAMETER PostInstallScript
    Path to a post-install script that should be run after the WinGet installation.
    This parameter is optional and only used during Install.
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]
    $WinGetID,

    [Parameter(Mandatory = $false)]
    [switch]
    $Install,

    [Parameter(Mandatory = $false)]
    [switch]
    $Uninstall,

    [Parameter(Mandatory = $false)]
    [string]
    $PreInstallScript,

    [Parameter(Mandatory = $false)]
    [string]
    $PostInstallScript
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- 1. Check Action (Install or Uninstall) ---
if (-not $Install -and -not $Uninstall) {
    throw "You must specify either -Install or -Uninstall."
}

if ($Install -and $Uninstall) {
    throw "You cannot specify both -Install and -Uninstall at the same time."
}

# --- 2. Define Logging Directory and Clean Up Old Logs ---
$LogDirectory = Join-Path -Path $env:ProgramData -ChildPath "WinGet-SigmatechLogs"
if (-not (Test-Path -Path $LogDirectory -PathType Container)) {
    New-Item -ItemType Directory -Path $LogDirectory | Out-Null
}

Write-Host "Cleaning up logs older than 60 days in: $LogDirectory"
Get-ChildItem -Path $LogDirectory -File -Recurse -Force -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-60) } |
    Remove-Item -Force -ErrorAction SilentlyContinue

# Create a timestamped log file
$TimeStamp = Get-Date -Format "yyyyMMdd-HHmmss"
$LogFile   = Join-Path -Path $LogDirectory -ChildPath "WinGet-$($TimeStamp).log"

# Simple helper function to write messages to console & log
function Write-Log {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Message
    )
    Write-Host $Message
    Add-Content -Path $LogFile -Value $Message
}

# --- 3. Function to Locate winget.exe ---
function Get-WinGetPath {
    Write-Log "Locating winget.exe..."

    # Attempt 1: Use Get-AppxPackage (works if we can see AppX packages in this context)
    try {
        $wingetPackage = Get-AppxPackage -Name "Microsoft.DesktopAppInstaller" -ErrorAction Stop
        if ($wingetPackage -and $wingetPackage.InstallLocation) {
            $potentialPath = Join-Path $wingetPackage.InstallLocation "winget.exe"
            if (Test-Path $potentialPath) {
                Write-Log "Found winget.exe via Get-AppxPackage: $potentialPath"
                return $potentialPath
            }
        }
    }
    catch {
        Write-Log "Get-AppxPackage for Microsoft.DesktopAppInstaller failed or not available."
    }

    # Attempt 2: Look within the standard WindowsApps directory
    $windowsAppsPath = Join-Path $env:ProgramFiles "WindowsApps"
    if (Test-Path $windowsAppsPath) {
        $wingetPaths = Get-ChildItem -Path $windowsAppsPath -Recurse -Filter "winget.exe" -ErrorAction SilentlyContinue
        if ($wingetPaths) {
            # If multiple are found, pick the most recently modified
            $chosen = $wingetPaths | Sort-Object LastWriteTime -Descending | Select-Object -First 1
            Write-Log "Found winget.exe via file search: $($chosen.FullName)"
            return $chosen.FullName
        }
    }

    # Attempt 3: If winget is on system PATH, we might find it simply by calling 'where.exe'
    try {
        $pathExe = & where.exe winget 2>$null
        if ($pathExe) {
            Write-Log "Found winget.exe via 'where.exe': $($pathExe)"
            return $pathExe
        }
    }
    catch {
        Write-Log "Unable to find winget via 'where.exe'."
    }

    Write-Log "ERROR: Could not find winget.exe in any known location."
    throw "winget.exe not found."
}

$wingetPath = Get-WinGetPath

# --- 4. Install or Uninstall Logic ---

if ($Install) {
    # --- 4a. Run Pre-Install Script (if provided) ---
    if ($PreInstallScript) {
        if (Test-Path $PreInstallScript) {
            Write-Log "Running pre-install script: $PreInstallScript"
            try {
                & $PreInstallScript 2>&1 | Tee-Object -FilePath $LogFile -Append
            }
            catch {
                Write-Log "Pre-install script failed: $($_.Exception.Message)"
                throw
            }
        }
        else {
            Write-Log "Pre-install script not found at path: $PreInstallScript"
        }
    }

    # --- 4b. Run WinGet Install ---
    Write-Log "Installing WinGet package: $WinGetID"
    try {
        & $wingetPath install --id $WinGetID --silent --accept-package-agreements --accept-source-agreements 2>&1 |
            Tee-Object -FilePath $LogFile -Append
    }
    catch {
        Write-Log "WinGet install failed for '$WinGetID': $($_.Exception.Message)"
        throw
    }

    # --- 4c. Run Post-Install Script (if provided) ---
    if ($PostInstallScript) {
        if (Test-Path $PostInstallScript) {
            Write-Log "Running post-install script: $PostInstallScript"
            try {
                & $PostInstallScript 2>&1 | Tee-Object -FilePath $LogFile -Append
            }
            catch {
                Write-Log "Post-install script failed: $($_.Exception.Message)"
                throw
            }
        }
        else {
            Write-Log "Post-install script not found at path: $PostInstallScript"
        }
    }

    Write-Log "Installation for '$WinGetID' completed successfully."
}
elseif ($Uninstall) {
    # --- 4d. Run WinGet Uninstall (now with accept-all flags) ---
    Write-Log "Uninstalling WinGet package: $WinGetID"
    try {
        & $wingetPath uninstall --id $WinGetID --accept-package-agreements --accept-source-agreements 2>&1 |
            Tee-Object -FilePath $LogFile -Append
    }
    catch {
        Write-Log "WinGet uninstall failed for '$WinGetID': $($_.Exception.Message)"
        throw
    }

    Write-Log "Uninstallation for '$WinGetID' completed successfully."
}
