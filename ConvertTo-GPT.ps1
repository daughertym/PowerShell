<#

.SYNOPSIS
Convert disk partition style from MBR to GPT on computers.

.PARAMETER ComputerName
Specifies the computers to convert.

.INPUTS
None. You cannot pipe objects.

.OUTPUTS
None.

.EXAMPLE 
.\ConvertTo-GPT -ComputerName PC01,PC02,PC03

.EXAMPLE
.\ConvertTo-GPT (Get-Content C:\computers.txt) -ErrorAction SilentlyContinue

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

$InvokeCommandScriptBlock = {

    Write-Verbose "Converting $env:COMPUTERNAME" -Verbose
    
    MBR2GPT.EXE /convert /allowFullOS
}

$InvokeCommandParams = @{

    ComputerName = $ComputerList
    ScriptBlock = $InvokeCommandScriptBlock
    ErrorAction = $ErrorActionPreference
}

Invoke-Command @InvokeCommandParams
