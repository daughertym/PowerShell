<#

.SYNOPSIS
Set BIOS webcam/microphone setting on HP computers.

* This script only works on HP computers *

.PARAMETER ComputerName
Specifies the computer(s) to set BIOS setting on.

.PARAMETER IncludeError
Optional switch to include errors.

.INPUTS
You cannot pipe objects to Set-Bios_Webcam_Mic.ps1

.OUTPUTS
System.Object

.EXAMPLE
.\Set-Bios_Webcam_Mic.ps1 (Get-Content C:\computers.txt) -Webcam Enable -Microphone Enable

.EXAMPLE
.\Set-Bios_Webcam_Mic.ps1 (Get-Content C:\computers.txt) -Webcam Disable -Microphone Disable

.EXAMPLE
.\Set-Bios_Webcam_Mic.ps1 (Get-Content C:\computers.txt) -Webcam Enable -Microphone Enable -IncludeError -Verbose |
Export-Csv BiosSetting.csv -NoTypeInformation

.NOTES
Author: Matthew D. Daugherty
Date Modified: 18 July 2020

#>

#Requires -RunAsAdministrator

[CmdletBinding()]
param (

    # Mandatory parameter for one or more computer names
    [Parameter(Mandatory)]
    [string[]]
    $ComputerName,

    # Parameter for webcam
    [Parameter()]
    [ValidateSet('Enable','Disable')]
    [string]
    $Webcam,

    # Parameter for microphone
    [Parameter()]
    [ValidateSet('Enable','Disable')]
    [string]
    $Microphone,

    # Optional switch to include errors
    [Parameter()]
    [switch]
    $IncludeError
)

# ScriptBlock for Invoke-Command
$InvokeCommandScriptBlock = {

    $VerbosePreference = $Using:VerbosePreference

    Write-Verbose "Setting BIOS setting(s) on $env:COMPUTERNAME"

    $Result = [PSCustomObject]@{

        Webcam = $null
        Microphone = $null
        Error = $null
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

        # Set BIOS camera setting - Return code 0 = success
        $Result.Webcam = ($Bios.SetBiosSetting('Integrated Camera', $Using:Webcam, $Password_UTF)).Return

        # Set BIOS microphone setting - Return code 0 = success
        $Result.Microphone = ($Bios.SetBiosSetting('Integrated Microphone', $Using:Microphone, $Password_UTF)).Return
    }
    catch {

        $Result.Error = $_.FullyQualifiedErrorId
    }

    $Result
}

# Parameters for Invoke-Command
$InvokeCommandParams = @{

    ComputerName = $ComputerName
    ScriptBlock = $InvokeCommandScriptBlock
    ErrorAction = 'SilentlyContinue'
}

if ($IncludeError.IsPresent) {

    $InvokeCommandParams.Add('ErrorVariable','icmErrors')
}

Invoke-Command @InvokeCommandParams | ForEach-Object {

    [PSCustomObject]@{

        ComputerName = $_.PSComputerName.ToUpper()
        InvokeStatus = 'Success'
        Webcam = $_.Webcam
        Microphone = $_.Microphone
        Error = $_.Error
    }
}

if ($IncludeError.IsPresent) {

    if ($icmErrors) {

        foreach ($icmError in $icmErrors) {

            [PSCustomObject]@{

                ComputerName = $icmError.TargetObject.ToUpper()
                InvokeStatus = $icmError.FullyQualifiedErrorId
                Webcam = $null
                Microphone = $null
                Error = $null
            }
        }
    }
}
