<#

.SYNOPSIS
Invoke gpupdate /force on one or more computers.

.PARAMETER ComputerName
Specifies the computer(s) to invoke gpupdate /force on.

.PARAMETER InvokeParallel
Optional switch to Invoke-Command in parallel.

.PARAMETER IncludeError
Optional switch to include errors with InvokeParallel.

.INPUTS
String.

.OUTPUTS
None.

.EXAMPLE
.\Invoke-GPUpdate -ComputerName PC01,PC02,PC03

.EXAMPLE
Get-Content C:\computers.txt | .\Invoke-GPUpdate

.EXAMPLE
.\Invoke-GPUpdate -ComputerName (Get-Content C:\computers.txt) -InvokeParallel

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
            
        Write-Verbose "Invoking gpupdate /force on $env:COMPUTERNAME" -Verbose

        gpupdate.exe /force /wait:0 | Out-Null

    } # end $InvokeCommandScriptBlock
}

process {

    switch ($InvokeParallel.IsPresent) {

        'False' {

            foreach ($Computer in $ComputerName) {

                $Computer = $Computer.ToUpper()

                if (Test-Connection -ComputerName $Computer -Count 1 -Quiet) {

                    try {
                        
                        Invoke-Command -ComputerName $Computer -ErrorAction Stop -ScriptBlock $InvokeCommandScriptBlock
                    }
                    catch {

                        Write-Warning "Failed to Invoke-Command on $Computer"
                    }

                } # end if (Test-Connection)
                else {

                    Write-Warning "Test-Connection returned false on $Computer"
                }

            } # end foreach *$Computer in $ComputerName)
        }
        'True' {

            # Parameters for Invoke-Command
            $InvokeCommandParams = @{

                ComputerName = $ComputerName
                ScriptBlock = $InvokeCommandScriptBlock
                ErrorAction = 'SilentlyContinue'
            }

            Invoke-Command @InvokeCommandParams
        }

    } # end switch ($InvokeParallel.IsPresent)
}
