<#

.SYNOPSIS
Find computers with certain user in C:\Users

.PARAMETER ComputerName
Specifies the computers to query.

.PARAMETER UserName
Specifies the username to find.

.PARAMETER IncludeNonResponding
Optional switch to include nonresponding computers.

.INPUTS
None. You cannot pipe objects.

.OUTPUTS
System.Object

.EXAMPLE
.\Find-UserProfile (Get-Content C:\computers.txt) -UserName 'bob.smith' -ErrorAction SilentlyContinue

.EXAMPLE
.\Find-UserProfile (Get-Content C:\computers.txt) -UserName 'bob.smith' -IncludeNonResponding -Verbose |
Export-Csv bob.smith.csv -NoTypeInformation

.NOTES
Author: Matthew D. Daugherty
Date Modified: 26 July 2020

#>

[CmdletBinding()]
param (

    [Parameter(Mandatory)]
    [string[]]
    $ComputerName,

    [Parameter(Mandatory)]
    [string]
    $UserName,

    [Parameter()]
    [switch]
    $IncludeNonResponding
)

# Scriptblock for Invoke-Command
$InvokeCommandScriptBlock = {

    $VerbosePreference = $Using:VerbosePreference
    
    Write-Verbose "Checking for $Using:UserName on $env:COMPUTERNAME."

    $Result = [PSCustomObject]@{

        ComputerName = $env:COMPUTERNAME
        UserName = $Using:UserName
        Found = $false
        LastWriteTime = $null
    }

    if (Test-Path -Path "C:\Users\$Using:UserName") {

        $Result.Found = $true

        $Result.LastWriteTime = (Get-Item -Path "C:\Users\$Using:UserName").LastWriteTime
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
                    UserName = $null
                    Found = $null
                    LastWriteTime = $null
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
