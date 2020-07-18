<#

.SYNOPSIS
Get SDC version of one or more USAF Standard Desktop Configuration computers.

.PARAMETER ComputerName
Specifies the computer(s) to get SDC version from.

.PARAMETER InvokeParallel
Optional switch to Invoke-Command in parallel.

.PARAMETER IncludeError
Optional switch to include errors with InvokeParallel.

.INPUTS
String

.OUTPUTS
System.Object

.EXAMPLE
.\Get-SDCVersion (Get-Content C:\computers.txt)

.EXAMPLE
Get-SDCVersion C:\computers.txt | .\Get-InstallDate

.EXAMPLE
.\Get-SDCVersion (Get-Content C:\computers.txt) -InvokeParallel

.EXAMPLE
.\Get-SDCVersion (Get-Content C:\computers.txt) -InvokeParallel -IncludeError

.NOTES
Author: Matthew D. Daugherty
Date Modified: 17 July 2020

#>

[CmdletBinding()]
param (

    # Mandatory parameter for one or more computer names
    [Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
    [string[]]
    $ComputerName,

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

        Write-Warning 'Cannot accept pipeline input while using the InvokeParallel switch.'
        break
    }

    if ($ComputerName.Count -eq 1 -and $InvokeParallel.IsPresent) {

        Write-Warning 'The InvokeParallel switch cannot be used with only one computer name.'
        break
    }

    # Scriptblock for Invoke-Command
    $InvokeCommandScriptBlock = {

        $VerbosePreference = $Using:VerbosePreference
        
        Write-Verbose "Getting SDC version on $env:COMPUTERNAME"

        try {

            $GetItemPropertyParams = @{

                Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation'
                ErrorAction = 'Stop'
            }
            
            $SDCVersion = (Get-ItemProperty @GetItemPropertyParams).Model
        }
        catch {

            $SDCVersion = $_.FullyQualifiedErrorId
        }

        [PSCustomObject]@{

            SDCVersion = $SDCVersion
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
                    SDCVersion = $null
                }
        
                if (Test-Connection -ComputerName $Computer -Count 1 -Quiet) {
        
                    $Result.TestConnection = $true
        
                    try {
        
                        $InvokeResult = Invoke-Command -ComputerName $Computer -ErrorAction Stop -ScriptBlock $InvokeCommandScriptBlock
        
                        $Result.InvokeStatus = 'Succcess'
        
                        $Result.SDCVersion = $InvokeResult.SDCVersion
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

                [PSCustomObject]@{
            
                    ComputerName = $_.PSComputerName.ToUpper()
                    InvokeStatus = 'Success'
                    SDCVersion = $_.SDCVersion
                }
            }

            if ($IncludeError.IsPresent) {

                if ($icmErrors) {
            
                    foreach ($icmError in $icmErrors) {
            
                        [PSCustomObject]@{
            
                            ComputerName = $icmError.TargetObject.ToUpper()
                            InvokeStatus = $icmError.FullyQualifiedErrorId
                            SDCVersion = $null
                        }
                    }
            
                } # end if ($icmErrors)
            
            } # end if ($IncludeError.IsPresent)
        }

    } # end switch ($InvokeParallel.IsPresent)
}

end {}
