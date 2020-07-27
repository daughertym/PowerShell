<#

.SYNOPSIS
Invoke gpupdate /force on computers.

.PARAMETER ComputerName
Specifies the computers to invoke gpupdate /force on.

.INPUTS
None. You cannot pipe objects.

.OUTPUTS
System.Object

.EXAMPLE
.\Invoke-GPUpdate -ComputerName PC01,PC02,PC03

.EXAMPLE
.\Invoke-GPUpdate (Get-Content C:\computers.txt) -ErrorAction SilentlyContinue

.NOTES
Author: Matthew D. Daugherty
Date Modified: 27 July 2020

#>

[CmdletBinding()]
param (

    [Parameter(Mandatory)]
    [string[]]
    $ComputerName
)

# Scriptblock for Invoke-Command
$InvokeCommandScriptBlock = {

    $VerbosePreference = $Using:VerbosePreference
        
    Write-Verbose "Invoked gpupdate /force on $env:COMPUTERNAME." -Verbose

    gpupdate.exe /force /wait:0 | Out-Null
}

# Parameters for Invoke-Command
$InvokeCommandParams = @{

    ComputerName = $ComputerName
    ScriptBlock = $InvokeCommandScriptBlock
    ErrorAction = $ErrorActionPreference
}

Invoke-Command @InvokeCommandParams
