<#

.SYNOPSIS
Get Secure Boot state from computers.

.PARAMETER ComputerName
Specifies the computers to query.

.PARAMETER IncludeError
Optional switch to include nonresponding computers.

.INPUTS
None. You cannot pipe objects.

.OUTPUTS
System.Object

.EXAMPLE
.\Get-SecureBootState

.EXAMPLE
.\Get-SecureBootState -ComputerName PC01,PC02,PC03

.EXAMPLE
.\Get-SecureBootState (Get-Content C:\computers.txt) -ErrorAction SilentlyContinue

.EXAMPLE
.\Get-SecureBootState (Get-Content C:\computers.txt) -IncludeNonResponding -Verbose |
Export-Csv SecureBoot.csv -NoTypeInformation

.NOTES
Author: Matthew D. Daugherty
Date Modified: 2 August 2020

#>

#Requires -RunAsAdministrator

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
    
    Write-Verbose "Getting Secure Boot state on $env:COMPUTERNAME."

    $Result = [PSCustomObject]@{

        ComputerName = $env:COMPUTERNAME
        SecureBoot = $null
    }

    try {

        switch (Confirm-SecureBootUEFI -ErrorAction Stop) {

            'True' {$SecureBoot = 'Enabled'}
            'False' {$SecureBoot = 'Disabled'}
        }

        $Result.SecureBoot = $SecureBoot
    }
    catch [System.PlatformNotSupportedException] {

        $Result.SecureBoot = 'Not Supported'
    }

    $Result
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
                    SecureBoot = $null
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
