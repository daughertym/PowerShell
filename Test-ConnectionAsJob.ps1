<#

.SYNOPSIS
Test-Connection -AsJob on computers.

.PARAMETER ComputerName
Specifies the computer(s) to Test-Connection on.

.INPUTS
None. You cannot pipe objects to Test-ConnectionAsJob

.OUTPUTS
System.Object

.EXAMPLE
.\Test-Connection -ComputerName PC01,PC02,PC03

.EXAMPLE
.\Test-Connection -ComputerName PC01,PC02,PC03 -IncludeUnreachable

.EXAMPLE
.\Test-Connection (Get-Content C:\computers.txt)

.NOTES
Author: Matthew D. Daugherty
Date Modified: 17 July 2020

#>

param (

# Parameter for one or more computer names
[Parameter(Mandatory)]
[string[]]
$ComputerName,

# Optional switch to include unreachable computers
[Parameter()]
[switch]
$IncludeUnreachable

)

$Unreachable = New-Object System.Collections.ArrayList

$ComputerName | ForEach-Object { 

    Write-Verbose "Testing connection on $_"

    Test-Connection -ComputerName $_ -Count 1 -AsJob

} | Get-Job | Receive-Job -Wait -AutoRemoveJob | ForEach-Object {

    if ($_.StatusCode -eq 0) {

        [PSCustomObject]@{

            ComputerName = $_.Address.ToUpper()
            Reachable = $true
        }
    }
    else {

        [void]$Unreachable.Add($_.Address)
    }
}

if ($IncludeUnreachable.IsPresent) {

    foreach ($Computer in $Unreachable) {

        [PSCustomObject]@{

            ComputerName = $Computer.ToUpper()
            Reachable = $false
        }
    }
}
