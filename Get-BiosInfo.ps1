<#

.SYNOPSIS
Get BIOS info from computers.

.PARAMETER ComputerName
Specifies the computers to query.

.PARAMETER IncludeNonResonding
Optional switch to include nonresponding computers.

.INPUTS
None. You cannot pipe objects.

.OUTPUTS
System.Object

.EXAMPLE
.\Get-BiosInfo -ComputerName PC01,PC02,PC03

.EXAMPLE
.\Get-BiosInfo (Get-Content C:\computers.txt) -ErrorAction SilentlyContinue

.EXAMPLE
.\Get-BiosInfo (Get-Content C:\computers.txt) -Verbose -IncludeNonResponding |
Export-Csv BiosVersion.csv -NoTypeInformation

.NOTES
Author: Matthew D. Daugherty
Date Modified: 27 July 2020

#>

[CmdletBinding()]
param (

    [Parameter(Mandatory)]
    [string[]]
    $ComputerName,

    [Parameter()]
    [switch]
    $IncludeNonResponding
)


# Scriptblock for Invoke-Command
$InvokeCommandScriptBlock = {

    $VerbosePreference = $Using:VerbosePreference

    Write-Verbose "Getting BIOS version on $env:COMPUTERNAME."

    $BIOS = Get-CimInstance -ClassName Win32_BIOS -Verbose:$false

    $Result = [PSCustomObject]@{

        ComputerName = $env:COMPUTERNAME
        SerialNumber = $BIOS.SerialNumber
        Manufacturer = $BIOS.Manufacturer
        Version = $BIOS.Name
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
                    SerialNumber = $null
                    Manufacturer = $null
                    Version = $null
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
