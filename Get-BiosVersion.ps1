<#

.SYNOPSIS
Get BIOS version from computers.

.PARAMETER ComputerName
Specifies the computers to query.

.PARAMETER IncludeError
Optional switch to include errors.

.INPUTS
None. You cannot pipe objects.

.OUTPUTS
System.Object

.EXAMPLE
.\Get-BiosVersion -ComputerName PC01,PC02,PC03

.EXAMPLE
.\Get-BiosVersion (Get-Content C:\computers.txt)

.EXAMPLE
.\Get-BiosVersion (Get-Content C:\computers.txt) -Verbose -IncludeError |
Export-Csv BiosVersion.csv -NoTypeInformation

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

    Write-Verbose "Getting BIOS version on $env:COMPUTERNAME"

    $Result = [PSCustomObject]@{

        BiosVersion = $null
        Manufacturer = $null
        SerialNumber = $null
        Error = $null
    }

    try {
        
        $BIOS = Get-CimInstance Win32_BIOS -Verbose:$false -ErrorAction Stop

        $Result.BiosVersion = $BIOS.Name

        $Result.Manufacturer = $BIOS.Manufacturer

        $Result.SerialNumber = $BIOS.SerialNumber
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
        SerialNumber = $_.SerialNumber
        Manufacturer = $_.Manufacturer
        BiosVersion = $_.BiosVersion
        Error = $_.Error
    }
}

if ($IncludeError.IsPresent) {

    if ($icmErrors) {

        foreach ($icmError in $icmErrors) {

            [PSCustomObject]@{

                ComputerName = $icmError.TargetObject.ToUpper()
                SerialNumber = $null
                Manufacturer = $null
                BiosVersion = $null
                Error = $icmError.FullyQualifiedErrorId
            }
        }
    }
}
