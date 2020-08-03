<#

.SYNOPSIS
Get local user account info from computers.

.PARAMETER ComputerName
Specifies the computers to query.

.PARAMETER IncludeNonResponding
Optional switch to include nonresponding computers.

.INPUTS
None. You cannot pipe objects.

.OUTPUTS
System.Object

.EXAMPLE
.\Get-LocalUserInfo

.EXAMPLE
.\Get-LocalUserInfo | Where-Object Enabled

.EXAMPLE
.\Get-LocalUserInfo -ComputerName PC01,PC02,PC03 -ErrorAction SilentlyContinue

.EXAMPLE
.\Get-LocalUserInfo (Get-Content .\computers.txt) -IncludeNonResponding -Verbose |
Export-Csv UserInfo.csv -NoTypeInformation

.NOTES
Author: Matthew D. Daugherty
Date Modified: 2 August 2020

#>

[CmdletBinding()]
param (

    [Parameter()]
    [string[]]
    $ComputerName = $env:COMPUTERNAME,

    [Parameter()]
    [switch]
    $IncludeNonResponding
)

# Scriptblock for Invoke-Command
$InvokeCommandScriptBlock = {

    $VerbosePreference = $Using:VerbosePreference
    
    Write-Verbose "Getting local user info on $env:COMPUTERNAME."

    $ResultsArray = @()

    foreach ($LocalUser in Get-LocalUser) {

        $LocalUserInfo = [PSCustomObject]@{

            ComputerName = $env:COMPUTERNAME
            LocalUser = $LocalUser.Name
            LastLogon = $LocalUser.LastLogon
            Enabled = $LocalUser.Enabled
            GroupMembership = $null
        }

        $GroupArray = @()

        foreach ($Group in Get-LocalGroup) {
    
            # If local user is a member of the current group in loop
            if (Get-LocalGroupMember -Name $Group -Member $LocalUser -ErrorAction SilentlyContinue) {

                # Add the name of the group to $GroupArray
                $GroupArray += $Group.Name 
            }
        }

        $GroupMembership = $GroupArray -join ", "

        $LocalUserInfo.GroupMembership = $GroupMembership

        $ResultsArray += $LocalUserInfo
    }

    $ResultsArray
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
                    LocalUser = $null
                    LastLogon = $null
                    Enabled = $null
                    GroupMembership = $null
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
