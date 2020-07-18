<#

.SYNOPSIS
Get last boot up time on one or more computers.

.PARAMETER ComputerName
Specifies the computer(s) to get last boot up time from.

.PARAMETER InvokeParallel
Optional switch to Invoke-Command in parallel.

.PARAMETER IncludeError
Optional switch to include errors with InvokeParallel.

.INPUTS
String

.OUTPUTS
System.Object

.EXAMPLE
.\Get-LastBootUpTime (Get-Content C:\computers.txt)

.EXAMPLE
Get-Content C:\computers.txt | .\Get-LastBootUpTime

.EXAMPLE
.\Get-LastBootUpTime (Get-Content C:\computers.txt) -InvokeParallel

.EXAMPLE
.\Get-LastBootUpTime (Get-Content C:\computers.txt) -InvokeParallel -IncludeError

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

    # Optional switch to include errors
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
        
        Write-Verbose "Getting LastBootUpTime on $env:COMPUTERNAME"

        try {
            
            $LastBootUpTime = (Get-CimInstance Win32_OperatingSystem -Verbose:$false -ErrorAction Stop).LastBootUpTime
        }
        catch {

            $LastBootUpTime = $_.FullyQualifiedErrorId
        }

        [PSCustomObject]@{

            LastBootUpTime = $LastBootUpTime
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
                    LastBootUpTime = $null
                }

                if (Test-Connection -ComputerName $Computer -Count 1 -Quiet) {

                    $Result.TestConnection = $true

                    try {
                        
                        $InvokeResult = Invoke-Command -ComputerName $Computer -ErrorAction Stop -ScriptBlock $InvokeCommandScriptBlock

                        $Result.InvokeStatus = 'Success'

                        $Result.LastBootUpTime = $InvokeResult.LastBootUpTime
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
                    LastBootUpTime = $_.LastBootUpTime
                }
            }

            if ($IncludeError.IsPresent) {

                if ($icmErrors) {
            
                    foreach ($icmError in $icmErrors) {
            
                        [PSCustomObject]@{
            
                            ComputerName = $icmError.TargetObject.ToUpper()
                            InvokeStatus = $icmError.FullyQualifiedErrorId
                            LastBootUpTime = $null
                        }
                    }
            
                } # end if ($icmErrors)
            
            } # end if ($PSBoundParameters)
        }

    } # end switch ($InvokeParallel.IsPresent)

} # end process

end {}
