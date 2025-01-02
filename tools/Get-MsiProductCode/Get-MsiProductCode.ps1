<#
.SYNOPSIS
    Retrieves the ProductCode from a specified MSI file without installing it.

.DESCRIPTION
    This script uses the WindowsInstaller.Installer COM object to open the MSI
    database in read-only mode and query the Property table to get the ProductCode.

.PARAMETER MsiPath
    The full path to the MSI file from which the ProductCode will be extracted.

.EXAMPLE
    .\Get-MsiProductCode.ps1 -MsiPath "C:\Temp\Example.msi"

    This command will display the product code of Example.msi.
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true, 
               ValueFromPipeline=$true,
               Position=0)]
    [ValidateNotNullOrEmpty()]
    [string]$MsiPath
)

try {
    # Validate MSI path
    if (-not (Test-Path $MsiPath)) {
        throw "MSI file not found at path: $MsiPath"
    }

    # Verify file is accessible
    try {
        [System.IO.File]::OpenRead($MsiPath).Close()
    }
    catch {
        throw "Unable to access MSI file: $_"
    }

    # Create an instance of the Windows Installer COM object
    $installer = New-Object -ComObject WindowsInstaller.Installer

    # Open the MSI database (mode = 0 = read-only)
    try {
        $database = $installer.OpenDatabase($MsiPath, 0)
    }
    catch {
        throw "Failed to open MSI database: $_"
    }

    # Query the MSI's Property table for 'ProductCode'
    $sql = "SELECT `Value` FROM `Property` WHERE `Property` = 'ProductCode'"
    $view = $database.OpenView($sql)
    $view.Execute()
    $record = $view.Fetch()

    if ($record) {
        $productCode = $record.StringData(1)
        Write-Host "ProductCode: $productCode"
        return $productCode
    }
    else {
        Write-Warning "ProductCode property not found in the specified MSI."
    }

    # Clean up
    $view.Close()
}
catch {
    Write-Error "An error occurred: $_"
}
finally {
    if ($database) { [System.Runtime.Interopservices.Marshal]::ReleaseComObject($database) | Out-Null }
    if ($installer) { [System.Runtime.Interopservices.Marshal]::ReleaseComObject($installer) | Out-Null }
}
