<#

.SYNOPSIS
Set BIOS webcam/microphone setting on HP computers.

.PARAMETER ComputerName
Specifies the computers to set BIOS setting on.

.PARAMETER Webcam
Specifies webcam setting (Enable/Disable)

.PARAMETER Microphone
Specifies microphone setting (Enable/Disable)

.PARAMETER IncludeNonResponding
Optional switch to include nonresponding computers.

.INPUTS
String

.OUTPUTS
System.Object

.EXAMPLE
.\Set-Bios_Webcam_Mic.ps1 (Get-Content C:\computers.txt) -Webcam Enable -Microphone Enable

.EXAMPLE
Get-Content C:\computers.txt | .\Set-Bios_Webcam_Mic.ps1 -Webcam Disable -Microphone Disable

.EXAMPLE
.\Set-Bios_Webcam_Mic.ps1 (Get-Content C:\computers.txt) -Webcam Enable -Microphone Enable -IncludeNonResponding -Verbose |
Export-Csv BiosSetting.csv -NoTypeInformation

.NOTES
Author: Matthew D. Daugherty
Date Modified: 27 July 2020

#>

#Requires -RunAsAdministrator

[CmdletBinding()]
param (

    [Parameter(Mandatory)]
    [string[]]
    $ComputerName,

    [Parameter()]
    [ValidateSet('Enable','Disable')]
    [string]
    $Webcam,

    [Parameter()]
    [ValidateSet('Enable','Disable')]
    [string]
    $Microphone,

   [Parameter()]
   [switch]
   $IncludeNonResponding
)

# ScriptBlock for Invoke-Command
$InvokeCommandScriptBlock = {

    $VerbosePreference = $Using:VerbosePreference

    Write-Verbose "Setting BIOS setting(s) on $env:COMPUTERNAME"

    $Result = [PSCustomObject]@{

        ComputerName = $env:COMPUTERNAME
        Webcam = $null
        Microphone = $null
    }

    # Change this variable to your BIOS password
    $Password = 'password'

    $Password_UTF = "<utf-16/>"+$Password

    try {

        # Parameters for Get-WmiObject
        $GetWmiObjectParams = @{

            NameSpace = 'root/hp/instrumentedBIOS'
            Class = 'HP_BiosSettingInterface'
            ErrorAction = 'Stop'
        }

        $Bios = Get-WmiObject @GetWmiObjectParams

        if ($Using:Webcam) {

            $Result.Webcam = ($Bios.SetBiosSetting('Integrated Camera', $Using:Webcam, $Password_UTF)).Return

            switch ($Return) {

                0 {$Result.Webcam = 'Success'}
                Default {$Result.Webcam = $Return}
            }
        }

        if ($Using:Microphone) {

            $Result.Microphone = ($Bios.SetBiosSetting('Integrated Microphone', $Using:Microphone, $Password_UTF)).Return

            switch ($Return) {

                0 {$Result.Microphone = 'Success'}
                Default {$Result.microphone = $Return}
            }
        }
    }
    catch {

        if ($Using:Webcam) {$Result.Webcam = 'Not supported'}

        if ($Using:Microphone) {$Result.Microphone = 'Not supported'}
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
                    Webcam = $null
                    Microphone = $null
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
