<#

.SYNOPSIS
Get OS install date from computers.

.PARAMETER ComputerName
Specifies the computers to query.

.PARAMETER IncludeError
Optional switch to include errors.

.INPUTS
None. You cannot pipe objects.

.OUTPUTS
System.Object

.EXAMPLE
.\Get-InstallDate -ComputerName PC01,PC02,PC03

.EXAMPLE
.\Get-InstallDate (Get-Content C:\computers.txt) -IncludeError

.EXAMPLE
.\Get-InstallDate (Get-Content C:\computers.txt) -IncludeError -Verbose |
Export-Csv InstallDate.csv -NoTypeInformation

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

    Write-Verbose "Getting OS install date on $env:COMPUTERNAME"

    $Result = [PSCustomObject]@{

        InstallDate = $null
        Error = $null
    }

    try {
        
        $InstallDate = (Get-CimInstance Win32_OperatingSystem -Verbose:$false -ErrorAction Stop).InstallDate

        $Result.InstallDate = $InstallDate
    }
    catch {

        $Result.Error = "$($_.CategoryInfo.Reason): $($_.CategoryInfo.TargetName)"
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
        InstallDate = $_.InstallDate
        Error = $_.Error
    }
}

if ($IncludeError.IsPresent) {

    if ($icmErrors) {

        foreach ($icmError in $icmErrors) {

            [PSCustomObject]@{

                ComputerName = $icmError.TargetObject.ToUpper()
                InstallDate = $null
                Error = $icmError.FullyQualifiedErrorId
            }
        }
    }
}
