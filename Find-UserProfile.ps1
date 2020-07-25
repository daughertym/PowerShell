<#

.SYNOPSIS
Find a user profile on computers.

.PARAMETER ComputerName
Specifies the computers to query.

.PARAMETER UserName
Specifies the username to find.

.PARAMETER IncludeError
Optional switch to include errors.

.INPUTS
None. You cannot pipe objects.

.OUTPUTS
System.Object

.EXAMPLE
.\Find-UserProfile (Get-Content C:\computers.txt) -UserName 'bob.smith'

.EXAMPLE
.\Find-UserProfile (Get-Content C:\computers.txt) -UserName 'bob.smith' -IncludeError

.EXAMPLE
.\Find-UserProfile (Get-Content C:\computers.txt) -UserName 'bob.smith' -Verbose |
Export-Csv bob.smith.csv -NoTypeInformation

.NOTES
Author: Matthew D. Daugherty
Date Modified: 25 July 2020

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
    $IncludeError
)

# Scriptblock for Invoke-Command
$InvokeCommandScriptBlock = {

    $VerbosePreference = $Using:VerbosePreference
    
    Write-Verbose "Checking for $Using:UserName on $env:COMPUTERNAME"

    $Result = [PSCustomObject]@{

        UserProfileFound = $false
        LastWriteTime = $null
    }

    if (Test-Path -Path "C:\Users\$Using:UserName") {

        $Result.UserProfileFound = $true

        $Result.LastWriteTime = (Get-Item -Path "C:\Users\$Using:UserName").LastWriteTime
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
        UserName = $UserName
        UserProfileFound = $_.UserProfileFound
        LastWriteTime = $_.LastWriteTime
        Error = $null
    }
}

if ($IncludeError.IsPresent) {

    if ($icmErrors) {

        foreach ($icmError in $icmErrors) {

            [PSCustomObject]@{

                ComputerName = $icmError.TargetObject.ToUpper()
                UserName = $null
                UserProfileFound = $null
                LastWriteTime = $null
                Error = $icmError.FullyQualifiedErrorId
            }
        }
    }
}
