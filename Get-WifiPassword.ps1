<#

.SYNOPSIS
Get wifi password.

.PARAMETER ComputerName
Specifies the computer to query.

.PARAMETER IncludeNonResonding
Optional switch to include nonresponding computers.

.INPUTS
None. You cannot pipe objects.

.OUTPUTS
System.Object

.EXAMPLE 
.\Get-WifiPassword

.EXAMPLE 
.\Get-BiosInfo -ComputerName PC01,PC02,PC03

.EXAMPLE
.\Get-BiosInfo (Get-Content C:\computers.txt) -Verbose -IncludeNonResponding -ErrorAction SilentlyContinue |
Export-Csv WifiPasswords.csv -NoTypeInformation

.NOTES
Author: Matthew D. Daugherty
Date Modified: 31 August 2020

#>

[CmdletBinding()]
param (

    [Parameter()]
    [string[]]
    $ComputerName = $env:COMPUTERNAME,

    [Parameter()]
    [switch]
    $IncludeNonResponding
)


# Scriptblock for Invoke-Command
$InvokeCommandScriptBlock = {

    $VerbosePreference = $Using:VerbosePreference

    Write-Verbose "Getting Wifi passwords on $env:COMPUTERNAME."

    $Profiles = netsh wlan show profiles | 
        Select-String -Pattern 'All User Profile' | 
        Foreach-Object {$_.ToString().Split(':')[-1].Trim()}

        $Profiles | Foreach-Object {

            $Password = netsh wlan show profiles name=$_ key='clear' | 
            Select-String -Pattern 'Key Content' | 
            Foreach-Object {$_.ToString().Split(':')[-1].Trim()}
            
            [PSCustomObject]@{

                ComputerName = $env:COMPUTERNAME
                SSID = $_
                Password = $Password
            }
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
                    SSID = $null
                    Password = $null
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
