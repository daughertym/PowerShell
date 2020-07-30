<#

.SYNOPSIS
Find SSID in netsh wlan show profiles on computers.

Shows which computers have connected to a certain WiFi.

.PARAMETER ComputerName
Specifies the computers to query.

.PARAMETER IncludeNonResponding
Optional switch to include nonresponding computers.

.INPUTS
None. You cannot pipe objects.

.OUTPUTS
System.object

.EXAMPLE
.\Find-SSID -ComputerName PC01,PC02,PC03 -SSID SomeSSID

.EXAMPLE
.\Find-SSID -ComputerName PC01,PC02,PC03 -SSID SomeSSID -IncludeNonResponding

.EXAMPLE
.\Find-SSID (Get-Content C:\computers.txt) -Verbose -ErrorAction SilentlyContinue |
Export-Csv FindSSID.csv -NoTypeInformation

.NOTES
Author: Matthew D. Daugherty
Date Modified: 29 July 2020

#>

[CmdletBinding()]
param (

    [Parameter(Mandatory)]
    [string[]]
    $ComputerName,

    [Parameter()]
    [string]
    $SSID,

    [Parameter()]
    [switch]
    $IncludeNonResponding
)

# Scriptblock for Invoke-Command
$InvokeCommandScriptBlock = {

    $VerbosePreference = $Using:VerbosePreference

    Write-Verbose "Querying $env:COMPUTERNAME for SSID $Using:SSID"

    $Result = [PSCustomObject]@{

        ComputerName = $env:COMPUTERNAME
        SSID = $Using:SSID
        Found = $false
    }

    $SSIDs = netsh wlan show profiles | 
    Select-String -Pattern 'All User Profile' | 
    Foreach-Object {$_.ToString().Split(':')[-1].Trim()}

    if ($SSIDs -contains $Using:SSID) {

        $Result.Found = $true
    }

    $Result
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
                    SSID = $null
                    Found = $null
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
