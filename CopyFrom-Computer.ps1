<#

.SYNOPSIS
Copy file from computer.

.PARAMETER ComputerName
Specifies the computer to copy file from.

.PARAMETER Path
Specifies the path to the file to copy.

.PARAMETER Destination
Specifies the destination to copy file to.

.PARAMETER IncludeError
Optional switch to include nonresponding computers.

.INPUTS
None. You cannot pipe objects.

.OUTPUTS
System.Object

.EXAMPLE
.\CopyFrom-Computer -ComputerName PC01,PC02,PC03 -Path C:\SomePath\SomeFile -Destintion \\xxxx\c$\SomePath

.EXAMPLE
.\CopyFrom-Computer (Get-Content C:\computers.txt )-Path C:\SomePath\SomeFile -Destintion \\xxxx\c$\SomePath -IncludeNonResponding

.NOTES
Author: Matthew D. Daugherty
Date Modified: 31 August 2020

#>

[CmdletBinding()]
param (

    [Parameter(Mandatory)]
    [string[]]
    $ComputerName,

    [Parameter(Mandatory)]
    [string]
    $Path,

    [Parameter(Mandatory)]
    [string]
    $Destination,

    [Parameter()]
    [switch]
    $IncludeNonResponding
)

$FileName = Split-Path -Path $Path -Leaf

# Scriptblock for Invoke-Command
$InvokeCommandScriptBlock = {

    $VerbosePreference = $Using:VerbosePreference

    Write-Verbose "Copying $($Using:FileName) from $env:COMPUTERNAME."

    $Result = [PSCustomObject]@{

        ComputerName = $env:COMPUTERNAME
        FileName = $Using:FileName
        FileExists = $false
        FileCopied = $false
    }

    if (Test-Path -Path $Using:Path) {

        $Result.FileExists = $true

        $Destination = "$Using:Destination\$($env:COMPUTERNAME)_$Using:FileName"

        Copy-Item -Path $Using:Path -Destination $Destination -Force

        if (Test-Path -Path $Destination) {

            $Result.FileCopied = $true
        }
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
                    FileExists = $null
                    FileCopied = $null
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
