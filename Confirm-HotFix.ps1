<#

.SYNOPSIS
Confirm if a certain hot fix is installed on computers.

.PARAMETER ComputerName
Specifies the computers to query.

.PARAMETER ID
Specifies the hot fix ID to check for.

.PARAMETER IncludeError
Optional switch to include errors.

.INPUTS
None.

.OUTPUTS
System.Object

.EXAMPLE
.\Confirm-HotFix -ComputerName PC01,PC02,PC03 -ID KB4559309

.EXAMPLE
.\Confirm-HotFix (Get-Content C:\computers.txt) -ID KB4559309 -IncludeError

.EXAMPLE
.\Confirm-HotFix (Get-Content C:\computers.txt) -ID KB4559309 -Verbose |
Export-Csv KB4559309.csv -NoTypeInformation

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
    $ID,

    [Parameter()]
    [switch]
    $IncludeError
)

$Pattern = 'KB\d{7}$'

if ($ID -match $Pattern) {

    # Scriptblock for Invoke-Command
    $InvokeCommandScriptBlock = {

        $VerbosePreference = $Using:VerbosePreference

        Write-Verbose "Checking $env:COMPUTERNAME for hotfix ID $Using:ID"

        $Result = [PSCustomObject]@{

            Installed = $false
            InstalledOn = $null
        }

        $HotFix = Get-HotFix -ID $Using:ID -ErrorAction SilentlyContinue

        if ($HotFix) {

            $Result.Installed = $true

            $Result.InstalledOn = $HotFix.InstalledOn
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
            HotFixId = $ID
            Installed = $_.Installed
            InstalledOn = $_.InstalledOn
            Error = $null
        }
    }

    if ($IncludeError.IsPresent) {

        if ($icmErrors) {

            foreach ($icmError in $icmErrors) {

                [PSCustomObject]@{

                    ComputerName = $icmError.TargetObject.ToUpper()
                    HotFixId = $null
                    Installed = $null
                    InstalledOn = $null
                    Error = $icmError.FullyQualifiedErrorId
                }
            }
        }
    }

} # end if ($ID -match $Pattern)
else {

    Write-Warning "$ID is not a valid hotfix ID."
}
