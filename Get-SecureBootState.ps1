<#

.SYNOPSIS
Get Secure Boot state from one or more computers.

.PARAMETER ComputerName
Specifies the computer(s) to get Secure Boot state from.

.PARAMETER IncludePartitionStyle
Optional switch to include partition style.

.PARAMETER InvokeParallel
Optional switch to Invoke-Command in parallel.

.PARAMETER IncludeError
Optional switch to include errors with InvokeParallel.

.INPUTS
String

.OUTPUTS
System.Object

.EXAMPLE
.\Get-SecureBootState (Get-Content C:\computers.txt)

.EXAMPLE
.\Get-SecureBootState (Get-Content C:\computers.txt) -IncludePartitionStyle

.EXAMPLE
Get-SecureBootState C:\computers.txt | .\Get-InstallDate

.EXAMPLE
.\Get-SecureBootState (Get-Content C:\computers.txt) -InvokeParallel

.EXAMPLE
.\Get-SecureBootState (Get-Content C:\computers.txt) -InvokeParallel -IncludePartitionStyle

.EXAMPLE
.\Get-SecureBootState (Get-Content C:\computers.txt) -InvokeParallel -IncludeError

.NOTES
Author: Matthew D. Daugherty
Date Modified: 17 July 2020

#>

#Requires -RunAsAdministrator

[CmdletBinding()]
param (

    # Mandatory parameter for one or more computer names
    [Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
    [string[]]
    $ComputerName,

    # Optional switch to Invoke-Command in parrallel
    [Parameter()]
    [switch]
    $IncludePartitionStyle,

    # Optional switch to Invoke-Command in parrallel
    [Parameter()]
    [switch]
    $InvokeParallel,

    # Optional switch to include errors with InvokeParallel
    [Parameter()]
    [switch]
    $IncludeError
)

begin {

    # Make sure InvokeParallel switch is not being used with piping input
    if ($InvokeParallel.IsPresent -and $MyInvocation.ExpectingInput) {

        Write-Warning "Cannot accept pipeline input while using the InvokeParallel switch."
        break
    }

    # Scriptblock for Invoke-Command
    $InvokeCommandScriptBlock = {

        $VerbosePreference = $Using:VerbosePreference
        
        Write-Verbose "Getting Secure Boot state on $env:COMPUTERNAME"

        try {

            switch (Confirm-SecureBootUEFI -ErrorAction Stop) {

                'True' {$SecureBoot = 'Enabled'}
                'False' {$SecureBoot = 'Disabled'}
            }
        }
        catch [System.PlatformNotSupportedException] {

            $SecureBoot = 'Not Supported'
        }
        catch [System.UnauthorizedAccessException] {

            $SecureBoot = 'Access was denied'
        }

        if ($Using:IncludePartitionStyle.IsPresent) {

            [PSCustomObject]@{

                SecureBootState = $SecureBoot
                PartitionStyle = (Get-Disk | Where-Object BootFromDisk).PartitionStyle
            }
        }
        else {

            [PSCustomObject]@{

                SecureBootState = $SecureBoot
            }
        }

    } # end $InvokeCommandScriptBlock
}

process {

    switch ($InvokeParallel.IsPresent) {

        'False' {

            foreach ($Computer in $ComputerName) {

                $Result = [PSCustomObject]@{

                    ComputerName = $Computer.ToUpper()
                    TestConnection = $false
                    InvokeStatus = $null
                    SecureBootState = $null
                }

                if ($IncludePartitionStyle.IsPresent) {

                    $Result | Add-Member -MemberType NoteProperty -Name PartitionStyle -Value $null
                }

                if (Test-Connection -ComputerName $Computer -Count 1 -Quiet) {

                    $Result.TestConnection = $true

                    try {

                        $InvokeResult = Invoke-Command -ComputerName $Computer -ErrorAction Stop -ScriptBlock $InvokeCommandScriptBlock

                        $Result.InvokeStatus = 'Success'

                        $Result.SecureBootState = $InvokeResult.SecureBootState

                        if ($IncludePartitionStyle.IsPresent) {

                            $Result.PartitionStyle = $InvokeResult.PartitionStyle
                        }
                    }
                    catch {

                        $Result.InvokeStatus = $_.FullyQualifiedErrorId
                    }

                } # end if (Test-Connection)

                $Result

            } # end foreach ($Computer in $ComputerName)
        }
        'True' {

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
    
                $Result = [PSCustomObject]@{
        
                    ComputerName = $_.PSComputerName.ToUpper()
                    InvokeStatus = 'Success'
                    SecureBootState = $_.SecureBootState
                }

                if ($IncludePartitionStyle.IsPresent) {

                    $Result | Add-Member -MemberType NoteProperty -Name 'PartitionStyle' -Value $_.PartitionStyle
                }

                $Result
            }

            if ($IncludeError.IsPresent) {

                if ($icmErrors) {
        
                    foreach ($icmError in $icmErrors) {
        
                        $Result = [PSCustomObject]@{
        
                            ComputerName = $icmError.TargetObject.ToUpper()
                            InvokeStatus = $icmError.FullyQualifiedErrorId
                            SecureBootState = $null
                        }

                        if ($IncludePartitionStyle.IsPresent) {

                            $Result | Add-Member -MemberType NoteProperty -Name 'PartitionStyle' -Value $null
                        }
        
                        $Result
                    }
        
                } # end if ($icmErrors)
        
            } # end if ($IncludeError.IsPresent)
        }

    } # end ($InvokeParallel.IsPresent)
}

end {}
