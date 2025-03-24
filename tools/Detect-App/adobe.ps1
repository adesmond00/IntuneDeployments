<#
.SYNOPSIS
    Intune Detection Script for Adobe Reader DC
.DESCRIPTION
    This script checks for the presence of Adobe Reader DC by examining:
    1. Adobe Reader DC's registry key in App Paths
    2. Common file paths where Adobe Reader DC executable is typically installed
    It will exit with:
      - 0 and write a success message if Adobe Reader DC is detected,
      - 1 otherwise.
#>
#region >>> Set Variables <
# Toggle whether to check registry key (True/False)
$CheckRegKey = $True
# Toggle whether to check file path (True/False)
$CheckFilePath = $True

# Registry key variables for Adobe Reader DC
$RegKeyPath   = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\AcroRd32.exe'
$RegValueName = ''   # empty since we just need to check if the key exists

# Adobe Reader DC file paths to check (we'll check all of these)
$AdobeReaderPaths = @(
    'C:\Program Files (x86)\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe', # Standard x86 installation
    'C:\Program Files\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe',       # Standard x64 installation
    'C:\Program Files (x86)\Adobe\Reader\Reader\AcroRd32.exe'             # Older Reader path
)
#endregion

#region >>> Helper Functions <
function Test-RegistryKeyExists {
    param (
        [string] $KeyPath,
        [string] $ValueName
    )
    # If ValueName is specified, check existence of the value;
    # otherwise, just check if the key exists.
    if (-not (Test-Path $KeyPath)) {
        return $False
    }
    if ($ValueName) {
        try {
            $value = Get-ItemProperty -Path $KeyPath -Name $ValueName -ErrorAction Stop
            if ($null -ne $value.$ValueName) {
                return $True
            }
            else {
                return $False
            }
        }
        catch {
            return $False
        }
    }
    else {
        # Key exists, no ValueName to check
        return $True
    }
}

function Test-AdobeReaderFilePathExists {
    param (
        [string[]] $Paths
    )
    
    foreach ($Path in $Paths) {
        if (Test-Path -Path $Path) {
            return $True
        }
    }
    
    # Also check potential user profile installation
    $UserProfilePath = "$env:LOCALAPPDATA\Adobe\Acrobat\DC\Reader\AcroRd32.exe"
    if (Test-Path -Path $UserProfilePath) {
        return $True
    }
    
    return $False
}
#endregion

#region >>> Detection Logic <
# Initialize flags
$RegistryExists = $False
$FileExists = $False

# Check registry if needed
if ($CheckRegKey) {
    $RegistryExists = Test-RegistryKeyExists -KeyPath $RegKeyPath -ValueName $RegValueName
}

# Check file paths if needed
if ($CheckFilePath) {
    $FileExists = Test-AdobeReaderFilePathExists -Paths $AdobeReaderPaths
}

# Determine result based on toggles
# 1. If both toggles are True, both must exist.
# 2. If only registry is True, only registry must exist.
# 3. If only file path is True, only file path must exist.
if ($CheckRegKey -and $CheckFilePath) {
    # Both checks must pass
    if ($RegistryExists -and $FileExists) {
        Write-Output "Adobe Reader DC detected via registry and file path."
        exit 0
    }
    else {
        exit 1
    }
}
elseif ($CheckRegKey -and -not $CheckFilePath) {
    # Only registry check
    if ($RegistryExists) {
        Write-Output "Adobe Reader DC detected via registry."
        exit 0
    }
    else {
        exit 1
    }
}
elseif (-not $CheckRegKey -and $CheckFilePath) {
    # Only file path check
    if ($FileExists) {
        Write-Output "Adobe Reader DC detected via file path."
        exit 0
    }
    else {
        exit 1
    }
}
else {
    # Neither option is True, so there's nothing to check -> fail
    exit 1
}
#endregion