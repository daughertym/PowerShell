<#

.SYNOPSIS
Enable Secure Boot on HP computers.

.PARAMETER ComputerName
Specifies the computers to enable Secure Boot on.

.INPUTS
None. You cannot pipe objects.

.OUTPUTS
None.

.EXAMPLE 
.\Enable-SecureBoot -ComputerName PC01,PC02,PC03

.EXAMPLE 
.\Enable-SecureBoot (Get-Content C:\computers.txt)

.EXAMPLE
.\Enable-SecureBoot (Get-Content C:\computers.txt) -ErrorAction SilentlyContinue

.NOTES
Author: Matthew D. Daugherty
Date Modified: 29 July 2020

#>

#Requires -RunAsAdministrator

[CmdletBinding()]
param (

    [Parameter(Mandatory)]
    [string[]]
    $ComputerName
)

# Scriptblock for Invoke-Command
$InvokeCommandScriptBlock = {
    
    Write-Verbose "Enabling Secure Boot on $env:COMPUTERNAME." -Verbose

    $BiosSettings = Get-WmiObject -Namespace root/hp/instrumentedBIOS -Class HP_BiosEnumeration

    $BiosPassword = 'password'
    $BiosPassword_UTF = "<utf-16/>$BiosPassword"
    $Bios = Get-WmiObject -Namespace root\HP\InstrumentedBIOS -Class HP_BiosSettingInterface

    if ($BiosSettings | Where-Object PossibleValues -Contains 'Legacy Support Disable and Secure Boot Enable') {

        [void]$Bios.SetBiosSetting('Configure Legacy Support and Secure Boot', 'Legacy Support Disable and Secure Boot Enable', $BiosPassword_UTF)
        [void]$Bios.SetBiosSetting('Legacy Boot Options', 'Disable', $BiosPassword_UTF)
        [void]$Bios.SetBiosSetting('UEFI Boot Options', 'Enable', $BiosPassword_UTF)
    }

    if ($BiosSettings | Where-Object PossibleValues -Contains 'Disable Legacy Support and Enable Secure Boot') {

        [void]$Bios.SetBiosSetting('Configure Legacy Support and Secure Boot', 'Disable Legacy Support and Enable Secure Boot', $BiosPassword_UTF)
        [void]$Bios.SetBiosSetting('Legacy Boot Options', 'Disable', $BiosPassword_UTF)
        [void]$Bios.SetBiosSetting('UEFI Boot Options', 'Enable', $BiosPassword_UTF)
    }

    if ($BiosSettings | Where-Object Name -eq 'Legacy Support') {

        [void]$Bios.SetBiosSetting('Legacy Support', 'Disable', $BiosPassword_UTF)
    }

    if ($BiosSettings | Where-Object Name -eq 'Secure Boot') {

        [void]$Bios.SetBiosSetting('Secure Boot', 'Enable', $BiosPassword_UTF)
    }

    if ($BiosSettings | Where-Object Name -eq 'SecureBoot') {

        [void]$Bios.SetBiosSetting('SecureBoot', 'Enable', $BiosPassword_UTF)
    }

    if ($BiosSettings | Where-Object Name -eq 'Boot Mode') {

        [void]$Bios.SetBiosSetting('Boot Mode', 'UEFI Native (Without CSM)', $BiosPassword_UTF)
    }

    # Restart computer if no user logged on
    $Quser = quser.exe 2>$null
    if ($null -eq $Quser) {Restart-Computer -Force}
}

# Parameters for Invoke-Command
$InvokeCommandParams = @{

    ComputerName = $ComputerName
    ScriptBlock = $InvokeCommandScriptBlock
    ErrorAction = $ErrorActionPreference
}

Invoke-Command @InvokeCommandParams 
