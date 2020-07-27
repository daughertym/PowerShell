<#

.SYNOPSIS
Get installed software from computers.

.PARAMETER ComputerName
Specifies the computers to query.

.PARAMETER Filter
Specifies the software to filter.

Supports wildcard *

-Filter Adobe would return any software that is like the name Adobe.

.PARAMETER Name
Specifies the name of the software.

If you know the exact name, you can query by name.

-Name 'Google Chrome'

.PARAMETER IncludeNonResonding
Optional switch to include nonresponding computers.

.INPUTS
None. You cannot pipe objects.

.OUTPUTS
System.Object

.EXAMPLE
.\Get-InstalledSoftware -ComputerName PC01,PC02,PC03 -Filter Adobe

.EXAMPLE
.\Get-InstalledSoftware -ComputerName PC01,PC02,PC03 -Name 'Google Chrome'

.EXAMPLE
.\Get-InstalledSoftware (Get-Content C:\computers.txt) -Name 'Google Chrome' -ErrorAction SilentlyContinue

.EXAMPLE
.\Get-InstalledSoftware (Get-Content C:\computers.txt) -Name 'Google Chrome' -Verbose -IncludeNonResponding |
Export-Csv Chrome.csv -NoTypeInformation

.EXAMPLE
.\Get-InstalledSoftware -ComputerName PC01 | Export-Csv InstalledSoftware.csv -NoTypeInformation

.NOTES
Author: Matthew D. Daugherty
Date Modified: 27 July 2020

#>

[CmdletBinding(DefaultParameterSetName = 'Filter')]
param (

    [Parameter()]
    [string[]]
    $ComputerName = $env:COMPUTERNAME,

    [Parameter(ParameterSetName = 'Filter')]
    [string]
    $Filter,

    [Parameter(ParameterSetName = 'Name')]
    [string]
    $Name,

    [Parameter()]
    [switch]
    $IncludeNonResponding
)


# Scriptblock for Invoke-Command
$InvokeCommandScriptBlock = {

    $VerbosePreference = $Using:VerbosePreference

    Write-Verbose "Getting installed software on $env:COMPUTERNAME."

    $ScriptBlock = {

        Get-ChildItem -Path 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall', 
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall' | Get-ItemProperty
    }

    if ($Using:Name) {

        $InstalledSoftware = Invoke-Command -ScriptBlock $ScriptBlock | Where-Object DisplayName -EQ $Using:Name

        $Query = $Using:Name
    }

    elseif ($Using:Filter) {

        $InstalledSoftware = Invoke-Command -ScriptBlock $ScriptBlock | Where-Object DisplayName -Like "*$Using:Filter*"

        $Query = $Using:Filter
    }
    else {

        $InstalledSoftware =  Invoke-Command -ScriptBlock $ScriptBlock
    }

    $Result = [PSCustomObject]@{

        ComputerName = $env:COMPUTERNAME
        Query = $Query
        SoftwareFound = $false
        DisplayName = $null
        Publisher = $null
        DisplayVersion = $null
        InstallDate = $null
        UninstallString = $null
    }

    if ($InstalledSoftware) {

        $InstalledSoftware | ForEach-Object {

            $Result.SoftwareFound = $true
            $Result.DisplayName = $_.DisplayName
            $Result.Publisher = $_.Publisher
            $Result.DisplayVersion = $_.DisplayVersion
            $Result.InstallDate = $_.InstallDate
            $Result.UninstallString = $_.UninstallString

            $Result
        }
    }
    else {

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
                    DisplayName = $null
                    Publisher = $null
                    DisplayVersion = $null
                    InstallDate = $null
                    UninstallString = $null
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
