<#

.SYNOPSIS
Get SDC version from USAF computers.

.PARAMETER ComputerName
Specifies the computers to query.

.PARAMETER IncludeError
Optional switch to include errors.

.INPUTS
None. You cannot pipe objects.

.OUTPUTS
System.Object

.EXAMPLE
.\Get-SDCVersion -ComputerName PC01,PC02,PC03

.EXAMPLE
.\Get-SDCVersion (Get-Content C:\computers.txt) -IncludeError

.EXAMPLE
.\Get-SDCVersion (Get-Content C:\computers.txt) -IncludeError -Verbose |
Export-Csv SDCVersion.csv -NoTypeInformation

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
    
    Write-Verbose "Getting SDC version on $env:COMPUTERNAME"

    $Result = [PSCustomObject]@{

        SDCVersion = $null
        Error = $null
    }

    try {

        $GetItemPropertyParams = @{

            Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation'
            ErrorAction = 'Stop'
        }
        
        $SDCVersion = (Get-ItemProperty @GetItemPropertyParams).Model

        $Result.SDCVersion = $SDCVersion
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
        SDCVersion = $_.SDCVersion
        Error = $_.Error
    }
}

if ($IncludeError.IsPresent) {

    if ($icmErrors) {

        foreach ($icmError in $icmErrors) {

            [PSCustomObject]@{

                ComputerName = $icmError.TargetObject.ToUpper()
                SDCVersion = $null
                Error = $icmError.FullyQualifiedErrorId
            }
        }
    }
}
