<#

.SYNOPSIS
Get disk info from computers.

.PARAMETER ComputerName
Specifies the computers to query.

.PARAMETER IncludeError
Optional switch to include nonresponding computers.

.INPUTS
None. You cannot pipe objects.

.OUTPUTS
System.Object

.EXAMPLE
.\Get-DiskInfo -ComputerName PC01,PC02,PC03

.EXAMPLE
.\Get-DiskInfo (Get-Content C:\computers.txt) -ErrorAction SilentlyContinue

.EXAMPLE
.\Get-DiskInfo (Get-Content C:\computers.txt) -IncludeNonResponding -Verbose |
Export-Csv DiskInfo.csv -NoTypeInformation

.NOTES
Author: Matthew D. Daugherty
Date Modified: 27 July 2020

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
    
    Write-Verbose "Getting disk info on $env:COMPUTERNAME."
    
    $Result = [PSCustomObject]@{

        ComputerName = $env:COMPUTERNAME
        DiskNumber = $null
        FriendlyName = $null
        OperationalStatus = $null
        PartitionStyle = $null
    }

    $VerbosePreference = 'SilentlyContinue'

    Get-Disk | ForEach-Object {

        $Result.DiskNumber = $_.Number
        $Result.FriendlyName = $_.FriendlyName
        $Result.OperationalStatus = $_.OperationalStatus
        $Result.PartitionStyle = $_.PartitionStyle

        $Result
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
                    DiskNumber = $null
                    FriendlyName = $null
                    OperationalStatus = $null
                    PartitionStyle = $null
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
