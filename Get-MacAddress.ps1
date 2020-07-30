<#

.SYNOPSIS
Get MAC address from computers.

.PARAMETER ComputerName
Specifies the computers to query.

.PARAMETER IncludeError
Optional switch to include nonresponding computers.

.INPUTS
None. You cannot pipe objects.

.OUTPUTS
System.Object

.EXAMPLE
.\Get-MacAddress -ComputerName PC01,PC02,PC03

.EXAMPLE
.\Get-MacAddress (Get-Content C:\computers.txt) -ErrorAction SilentlyContinue

.EXAMPLE
.\Get-MacAddress (Get-Content C:\computers.txt) -IncludeNonResponding -Verbose |
Export-Csv InstallDate.csv -NoTypeInformation

.NOTES
Author: Matthew D. Daugherty
Date Modified: 30 July 2020

#>

[CmdletBinding()]
param (

    [Parameter(Mandatory)]
    [string[]]
    $ComputerName,

    [Parameter()]
    [switch]
    $IncludeNonResponding
)


# Scriptblock for Invoke-Command
$InvokeCommandScriptBlock = {

    $VerbosePreference = $Using:VerbosePreference

    Write-Verbose "Getting MAC address on $env:COMPUTERNAME."

    $GetCimInstanceParams = @{

        ClassName = 'Win32_NetworkAdapterConfiguration'
        Filter = 'IPEnabled="True"'
        Verbose = $false
    }

    [PSCustomObject]@{

        ComputerName = $env:COMPUTERNAME
        MacAddress = (Get-CimInstance @GetCimInstanceParams).MacAddress
    }
}

# Parameters for Invoke-Command
$InvokeCommandParams = @{

    ComputerName = $ComputerName
    ScriptBlock = $InvokeCommandScriptBlock
    ErrorAction = $ErrorActionPreference
}

switch ($IncludeNonResponding.IsPresent) {

    'True' {

        $InvokeCommandParams.Add('ErrorVariable','NonResponding')

        Invoke-Command @InvokeCommandParams | 
        Select-Object -Property *, ErrorId -ExcludeProperty PSComputerName, PSShowComputerName, RunspaceId

        if ($NonResponding) {

            foreach ($Computer in $NonResponding) {

                [PSCustomObject]@{

                    ComputerName = $Computer.TargetObject.ToUpper()
                    MacAddress = $null
                    ErrorId = $Computer.FullyQualifiedErrorId
                }
            }
        }
    }
    'False' {

        Invoke-Command @InvokeCommandParams | 
        Select-Object -Property * -ExcludeProperty PSComputerName, PSShowComputerName, RunspaceId
    }
}
