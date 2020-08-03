<#

.SYNOPSIS
Get SDC version from USAF computers.

.PARAMETER ComputerName
Specifies the computers to query.

.PARAMETER IncludeError
Optional switch to include nonresponding computers.

.INPUTS
None. You cannot pipe objects.

.OUTPUTS
System.Object

.EXAMPLE
.\Get-SDCVersion

.EXAMPLE
.\Get-SDCVersion -ComputerName PC01,PC02,PC03

.EXAMPLE
.\Get-SDCVersion (Get-Content C:\computers.txt) -ErrorAction SilentlyContinue

.EXAMPLE
.\Get-SDCVersion (Get-Content C:\computers.txt) -IncludeNonResponding -Verbose |
Export-Csv SDCVersion.csv -NoTypeInformation

.NOTES
Author: Matthew D. Daugherty
Date Modified: 2 August 2020

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
    
    Write-Verbose "Getting SDC version on $env:COMPUTERNAME."

    $Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation'

    [PSCustomObject]@{

        ComputerName = $env:COMPUTERNAME
        SDCVersion = (Get-ItemProperty -Path $Path).Model
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
                    SDCVersion = $null
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
