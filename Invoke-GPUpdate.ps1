<#

.SYNOPSIS
Invoke gpupdate /force on computer(s).

.PARAMETER ComputerName
Specifies the computer(s) to invoke gpupdate /force on.

.PARAMETER IncludeError
Optional switch to include errors.

.INPUTS
None. You cannot pipe objects.

.OUTPUTS
System.Object

.EXAMPLE
.\Invoke-GPUpdate -ComputerName PC01,PC02,PC03

.EXAMPLE
.\Invoke-GPUpdate (Get-Content C:\computers.txt) -IncludeError

.NOTES
Author: Matthew D. Daugherty
Date Modified: 25 July 2020

#>

[CmdletBinding()]
param (

    [Parameter(Mandatory)]
    [string[]]
    $ComputerName,

    [Parameter()]
    [switch]
    $IncludeError
)

# Scriptblock for Invoke-Command
$InvokeCommandScriptBlock = {

    $VerbosePreference = $Using:VerbosePreference
        
    Write-Verbose "Invoking gpupdate /force on $env:COMPUTERNAME"

    gpupdate.exe /force /wait:0 | Out-Null

    [PSCustomObject]@{

        Success = $true
    }
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
        Success = $_.Success
        Error = $null
    }
}

if ($IncludeError.IsPresent) {

    if ($icmErrors) {

        foreach ($icmError in $icmErrors) {

            [PSCustomObject]@{

                ComputerName = $icmError.TargetObject.ToUpper()
                Success = $false
                Error = $icmError.FullyQualifiedErrorId
            }
        }
    }
}
