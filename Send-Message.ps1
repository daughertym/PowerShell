<#

.SYNOPSIS
Send message to one or more computers.

.PARAMETER ComputerName
Specifies the computer(s) to send message to.

.PARAMETER Message
Specifies the message to send.

If message contains spaces it must be surrounded by single or double quotes.

'This is an example message'

"This is an example message"

.PARAMETER InvokeParallel
Optional switch to Invoke-Command in parallel.

.PARAMETER IncludeError
Optional switch to include errors with InvokeParallel.

.PARAMETER AsLoop
Optional switch to send message as a continuous loop.

Messages will send every 15 minutes.

.INPUTS
String

.OUTPUTS
None.

.EXAMPLE
.\Send-Message -ComputerName PC01,PC01,PC03 -Message 'Hello World!'

.EXAMPLE
Get-Content .\computers.txt | .\Send-Message -Message 'Hello World!' -AsLoop

.EXAMPLE
.\Send-Message (Get-Content .\computers.txt) -Message 'Hello World!' -InvokeParallel

.EXAMPLE
.\Send-Message (Get-Content .\computers.txt) -Message 'Hello World!' -InvokeParallel -AsLoop

.NOTES
Author: Matthew D. Daugherty
Date Modified: 17 July 2020

#>

[CmdletBinding()]
param (

    # Mandatory parameter for one or more computer names
    [Parameter(Mandatory)]
    [string[]]
    $ComputerName,

    # Mandatory parameter for message
    [Parameter(Mandatory)]
    [string]
    $Message,

    # Optional switch to send message as a continuous loop
    [Parameter()]
    [switch]
    $AsLoop,

    # Optional switch to Invoke-Command in parrallel
    [Parameter()]
    [switch]
    $InvokeParallel
)

begin {

    if ($InvokeParallel.IsPresent -and $MyInvocation.ExpectingInput) {

        Write-Warning "Function cannot accept pipeline input while using the InvokeParallel switch."
        break
    }

    # Scriptblock for Invoke-Command
    $InvokeCommandScriptBlock = {

        msg.exe * $Using:Message

        Write-Verbose "Message sent to $env:COMPUTERNAME" -Verbose

    } # end $InvokeCommandScriptBlock
}

process {

    switch ($InvokeParallel.IsPresent) {

        'False' {

            do {

                foreach ($Computer in $ComputerName) {

                    try {

                        Invoke-Command -ComputerName $Computer -ErrorAction Stop -ScriptBlock $InvokeCommandScriptBlock
                    }
                    catch {

                        Write-Host "Failed to send message to $($Computer.ToUpper())" -ForegroundColor Red
                    }
                    
                } # end foreach ($Computer in $ComputerName)
    
                if ($AsLoop.IsPresent) {
    
                    # Sleep 15 minutes
                    Start-Sleep -Seconds 3
    
                    Clear-Host
    
                    $Loop = $true
                }
                else {
    
                    $Loop = $false
                }
    
            } until ($Loop -eq $false)
        }
        'True' {

            # Parameters for Invoke-Command
            $InvokeCommandParams = @{

                ComputerName = $ComputerName
                ScriptBlock = $InvokeCommandScriptBlock
                ErrorAction = 'SilentlyContinue'
                ErrorVariable = 'icmErrors'
            }

            do {

                Invoke-Command @InvokeCommandParams

                if ($icmErrors) {

                    foreach ($icmError in $icmErrors) {
    
                        Write-Host "Failed to send message to $($icmError.TargetObject.ToUpper())" -ForegroundColor Red
                    }
                }

                if ($AsLoop.IsPresent) {
    
                    # Sleep 15 minutes
                    Start-Sleep -Seconds 3
    
                    Clear-Host

                    Clear-Variable -Name $icmErrors
    
                    $Loop = $true
                }
                else {
    
                    $Loop = $false
                }

            } until ($Loop -eq $false)
        }

    } # end switch ($InvokeParallel.IsPresent)

} # end process

end {}
