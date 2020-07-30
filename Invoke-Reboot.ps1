<#

.SYNOPSIS
Invoke reboot of computers.

.PARAMETER ComputerName
Specifies the computers to reboot.

.PARAMETER Force
Optional switch to force reboot computers.

If -Force switch is not used, reboot will only happen if no user is logged on.

.PARAMETER IncludeNonResponding
Optional switch to include nonresponding computers.

.INPUTS
None. You cannot pipe objects.

.OUTPUTS
System.object

.EXAMPLE
.\Invoke-Reboot -ComputerName PC01,PC02,PC03

.EXAMPLE
.\Invoke-Reboot -ComputerName PC01,PC02,PC03 -Force

.EXAMPLE
.\Invoke-Reboot (Get-Content C:\computers.txt) -Verbose -ErrorAction SilentlyContinue |
Export-Csv Reboot.csv -NoTypeInformation

.NOTES
Author: Matthew D. Daugherty
Date Modified: 29 July 2020

#>

[CmdletBinding()]
param (

    [Parameter(Mandatory)]
    [string[]]
    $ComputerName,

    [Parameter()]
    [switch]
    $Force,

    [Parameter()]
    [switch]
    $IncludeNonResponding
)

# Scriptblock for Invoke-Command
$InvokeCommandScriptBlock = {

    $VerbosePreference = $Using:VerbosePreference

    $Result = [PSCustomObject]@{

        ComputerName = $env:COMPUTERNAME
        Rebooted = $false
    }

    switch ($Using:Force.IsPresent) {

        'True' {

            Write-Verbose "Rebooting $env:COMPUTERNAME."

            Restart-Computer -Verbose:$false -Force

            $Result.Rebooted = $true

            $Result
        }
        'False' {

            $Quser = quser.exe 2>$null

            # If no user is logged on
            if ($null -eq $Quser) {

                Write-Verbose "Rebooting $env:COMPUTERNAME."

                Restart-Computer -Verbose:$false -Force

                $Result.Rebooted = $true

                $Result
            }
            else {

                Write-Verbose "A user is logged on $env:COMPUTERNAME. Not rebooting."

                $Result
            }
        }
    }
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
                    Rebooted = $null
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
