<#

.SYNOPSIS
Get last boot up time from computers.

.PARAMETER ComputerName
Specifies the computers query.

.PARAMETER IncludeError
Optional switch to include errors.

.INPUTS
None. You cannot pipe objects.

.OUTPUTS
System.Object

.EXAMPLE
.\Get-LastBootUpTime -ComputerName PC01,PC02,PC03

.EXAMPLE
.\Get-LastBootUpTime (Get-Content C:\computers.txt) -IncludeError

.EXAMPLE
.\Get-LastBootUpTime (Get-Content C:\computers.txt) -IncludeError -Verbose |
Export-Csv LastBootUpTime.csv -NoTypeInformation

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
    
    Write-Verbose "Getting LastBootUpTime on $env:COMPUTERNAME"

    $Result = [PSCustomObject]@{

        LastBootUpTime = $null
        Error = $null
    }

    try {
        
        $LastBootUpTime = (Get-CimInstance Win32_OperatingSystem -Verbose:$false -ErrorAction Stop).LastBootUpTime

        $Result.LastBootUpTime = $LastBootUpTime
    }
    catch {

        $LastBootUpTime.Error = $_.FullyQualifiedErrorId
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
        LastBootUpTime = $_.LastBootUpTime
        Error = $_.Error
    }
}

if ($IncludeError.IsPresent) {

    if ($icmErrors) {

        foreach ($icmError in $icmErrors) {

            [PSCustomObject]@{

                ComputerName = $icmError.TargetObject.ToUpper()
                InvokeStatus = $icmError.FullyQualifiedErrorId
                LastBootUpTime = $null
            }
        }
    }
}
