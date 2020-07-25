<#

.SYNOPSIS
Get Secure Boot state from computers.

.PARAMETER ComputerName
Specifies the computers to query.

.PARAMETER IncludePartitionStyle
Optional switch to include partition style.

.PARAMETER IncludeError
Optional switch to include errors.

.INPUTS
None. You cannot pipe objects.

.OUTPUTS
System.Object

.EXAMPLE
.\Get-SecureBootState -ComputerName PC01,PC02,PC03

.EXAMPLE
.\Get-SecureBootState (Get-Content C:\computers.txt) -IncludePartitionStyle

.EXAMPLE
.\Get-SecureBootState (Get-Content C:\computers.txt) -IncludeError -Verbose |
Export-Csv SecureBoot.csv -NoTypeInformation

.NOTES
Author: Matthew D. Daugherty
Date Modified: 25 July 2020

#>

#Requires -RunAsAdministrator

[CmdletBinding()]
param (

    [Parameter(Mandatory)]
    [string[]]
    $ComputerName,

    [Parameter()]
    [switch]
    $IncludePartitionStyle,

    [Parameter()]
    [switch]
    $IncludeError
)

# Scriptblock for Invoke-Command
$InvokeCommandScriptBlock = {

    $VerbosePreference = $Using:VerbosePreference
    
    Write-Verbose "Getting Secure Boot state on $env:COMPUTERNAME"

    $Result = [PSCustomObject]@{

        SecureBootState = $null
        PartitionStyle = $null
        Error = $null
    }

    try {

        switch (Confirm-SecureBootUEFI -Verbose:$false -ErrorAction Stop) {

            'True' {$SecureBoot = 'Enabled'}
            'False' {$SecureBoot = 'Disabled'}
        }

        $Result.SecureBootState = $SecureBoot
    }
    catch [System.PlatformNotSupportedException] {

        $SecureBoot = 'Not Supported'
    }
    catch [System.UnauthorizedAccessException] {

        $Result.Error = 'Confirm-SecureBootUEFI: Access denied'
    }

    if ($Using:IncludePartitionStyle.IsPresent) {

        try {

            $PartitionStyle = (Get-Disk -Verbose:$false -ErrorAction Stop).PartitionStyle

            if ($PartitionStyle.Count -gt 1) {

                $PartitionStyle = $PartitionStyle -join ','
            }

            $Result.PartitionStyle = $PartitionStyle
        }
        catch {

            $Result.Error = $_.FullyQualifiedErrorId
        }
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

    if ($IncludePartitionStyle.IsPresent) {

        [PSCustomObject]@{

            ComputerName = $_.PSComputerName.ToUpper()
            SecureBootState = $_.SecureBootState
            PartitionStyle = $_.PartitionStyle
            Error = $_.Error
        }
    }
    else {

        [PSCustomObject]@{

            ComputerName = $_.PSComputerName.ToUpper()
            SecureBootState = $_.SecureBootState
            Error = $_.Error
        }
    }
}

if ($IncludeError.IsPresent) {

    if ($icmErrors) {

        foreach ($icmError in $icmErrors) {

            if ($IncludePartitionStyle.IsPresent) {

                [PSCustomObject]@{

                    ComputerName = $icmError.TargetObject.ToUpper()
                    SecureBootState = $null
                    PartitionStyle = $null
                    Error = $icmError.FullyQualifiedErrorId
                }
            }
            else {

                [PSCustomObject]@{

                    ComputerName = $icmError.TargetObject.ToUpper()
                    SecureBootState = $null
                    Error = $icmError.FullyQualifiedErrorId
                }
            }
        }
    }
}
