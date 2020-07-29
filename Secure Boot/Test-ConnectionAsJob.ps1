<#

.SYNOPSIS
Test-Connection -AsJob on computers.

.PARAMETER ComputerName
Specifies the computers to Test-Connection on.

If no computer names are passed to ComputerName parameter,
computer names will be from Active Directory.

.INPUTS
None. You cannot pipe objects.

.OUTPUTS
System.Object

.EXAMPLE
.\Test-Connection -ComputerName PC01,PC02,PC03

.EXAMPLE
.\Test-Connection (Get-Content .\computers.txt) -IncludeUnreachable -Verbose |
Export-Csv TestConnection.csv -NoTypeInformation

.EXAMPLE
$Reachable = (.\Test-Connection).ComputerName

.EXAMPLE
.\Test-Connection | Select-Object -ExpandProperty ComputerName |
Out-File Reachable.txt

.NOTES
Author: Matthew D. Daugherty
Date Modified: 27 July 2020

#>

param (

[Parameter()]
[string[]]
$ComputerName,

[Parameter()]
[switch]
$IncludeUnreachable

)

if (-not($PSBoundParameters.ContainsKey('ComputerName'))) {

    if (-not(Get-Module -ListAvailable -Name 'ActiveDirectory')) {

        Write-Warning "Active Directory module is not installed."
        break
    } 

    # Change this variable to your OUs
    $SearchBases = @(

        'OU=Domain Users,OU=daugherty,DC=daugherty,DC=com'
        'xxx'
        'xxx'
    )

    $ComputerName = $SearchBases | ForEach-Object {

        (Get-ADComputer -SearchBase $_ -Filter *).Name
    }
}

$Unreachable = New-Object System.Collections.ArrayList

$ComputerName | ForEach-Object { 

    Write-Verbose "Testing connection on $_."

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
