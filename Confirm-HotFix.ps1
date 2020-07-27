<#

.SYNOPSIS
Confirm if a certain hot fix is installed on computers.

.PARAMETER ComputerName
Specifies the computers to query.

.PARAMETER ID
Specifies the hot fix ID to check for.

.PARAMETER IncludeError
Optional switch to include nonresponding computers.

.INPUTS
None. You cannot pipe objects.

.OUTPUTS
System.Object

.EXAMPLE
.\Confirm-HotFix -ComputerName PC01,PC02,PC03 -ID KB4559309

.EXAMPLE
.\Confirm-HotFix (Get-Content C:\computers.txt) -ID KB4559309

.EXAMPLE
.\Confirm-HotFix (Get-Content C:\computers.txt) -ID KB4559309 -IncludeNonResponding -Verbose |
Export-Csv KB4559309.csv -NoTypeInformation

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
    $ID,

    [Parameter()]
    [switch]
    $IncludeNonResponding
)

$Pattern = 'KB\d{7}$'

if ($ID -match $Pattern) {

    # Scriptblock for Invoke-Command
    $InvokeCommandScriptBlock = {

        $VerbosePreference = $Using:VerbosePreference

        Write-Verbose "Checking $env:COMPUTERNAME for hotfix ID $Using:ID."

        $Result = [PSCustomObject]@{

            ComputerName = $env:COMPUTERNAME
            HotFixID = $Using:ID
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

    switch ($IncludeNonResponding.IsPresent) {

        'True' {

            $InvokeCommandParams.Add('ErrorVariable','NonResponding')

            Invoke-Command @InvokeCommandParams | 
            Select-Object -Property *, ErrorId -ExcludeProperty PSComputerName, PSShowComputerName, RunspaceId

            if ($NonResponding) {

                foreach ($Computer in $NonResponding) {
    
                    [PSCustomObject]@{
    
                        ComputerName = $Computer.TargetObject.ToUpper()
                        HotFixID = $null
                        Installed = $null
                        InstalledOn = $null
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

} # end if ($ID -match $Pattern)
else {

    Write-Warning "[-ID] $ID is not proper format. Must be KB followed by 7 digits. Ex: KB1234567"
}
