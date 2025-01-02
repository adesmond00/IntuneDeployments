<#
.SYNOPSIS
    Intune Detection Script Example
.DESCRIPTION
    This script checks for the presence of a registry key and/or a file path
    based on toggle variables. It will exit with:
      - 0 and write a success message if detection is successful,
      - 1 otherwise.
#>

#region >>> Set Variables <<<

# Toggle whether to check registry key (True/False)
$CheckRegKey = $True

# Toggle whether to check file path (True/False)
$CheckFilePath = $True

# Registry key variables
# For HKLM or HKCU paths in PowerShell, use e.g. 'HKLM:\SOFTWARE\MyKey'
# or 'HKCU:\SOFTWARE\MyKey'
$RegKeyPath   = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion'
$RegValueName = 'ProgramFilesDir'   # optional if you want to verify a value

# File path to check
$FilePath = 'C:\Windows\Notepad.exe'

#endregion

#region >>> Helper Functions <<<

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

function Test-FilePathExists {
    param (
        [string] $Path
    )
    return (Test-Path -Path $Path)
}

#endregion

#region >>> Detection Logic <<<

# Initialize flags
$RegistryExists = $False
$FileExists     = $False

# Check registry if needed
if ($CheckRegKey) {
    $RegistryExists = Test-RegistryKeyExists -KeyPath $RegKeyPath -ValueName $RegValueName
}

# Check file path if needed
if ($CheckFilePath) {
    $FileExists = Test-FilePathExists -Path $FilePath
}

# Determine result based on toggles
# 1. If both toggles are True, both must exist.
# 2. If only registry is True, only registry must exist.
# 3. If only file path is True, only file path must exist.

if ($CheckRegKey -and $CheckFilePath) {
    # Both checks must pass
    if ($RegistryExists -and $FileExists) {
        Write-Output "Application detected via registry and file path."
        exit 0
    }
    else {
        exit 1
    }
}
elseif ($CheckRegKey -and -not $CheckFilePath) {
    # Only registry check
    if ($RegistryExists) {
        Write-Output "Application detected via registry."
        exit 0
    }
    else {
        exit 1
    }
}
elseif (-not $CheckRegKey -and $CheckFilePath) {
    # Only file path check
    if ($FileExists) {
        Write-Output "Application detected via file path."
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
