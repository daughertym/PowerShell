<#

.SYNOPSIS
Send message to computers.

.PARAMETER ComputerName
Specifies the computers to send message to.

.PARAMETER Message
Specifies the message to send.

If message contains spaces it must be surrounded by single or double quotes.

'This is an example message'

"This is an example message"

.PARAMETER AsLoop
Optional switch to send message as a continuous loop.

Message will send every 15 minutes.

.INPUTS
None. You cannot pipe objects.

.OUTPUTS
None.

.EXAMPLE
.\Send-Message -ComputerName PC01 -Message 'Hello World!'

.EXAMPLE
.\Send-Message -ComputerName (Get-Content C:\computers.txt) -Message 'Hello World!' -ErrorAction SilentlyContinue

.NOTES
Author: Matthew D. Daugherty
Date Modified: 27 July 2020

#>

[CmdletBinding()]
param (

    [Parameter(Mandatory)]
    [string[]]
    $ComputerName,

    [Parameter(Mandatory)]
    [string]
    $Message,

    [Parameter()]
    [switch]
    $AsLoop
)

# Scriptblock for Invoke-Command
$InvokeCommandScriptBlock = {

    msg.exe * $Using:Message

    Write-Verbose "Message sent to $env:COMPUTERNAME." -Verbose
}

# Parameters for Invoke-Command
$InvokeCommandParams = @{

    ComputerName = $ComputerName
    ScriptBlock = $InvokeCommandScriptBlock
    ErrorAction = $ErrorActionPreference
}

switch ($AsLoop.IsPresent) {

    'True' {

        while ($true) {

            Clear-Host

            Invoke-Command @InvokeCommandParams

            # Sleep for 15 minutes
            Start-Sleep -Seconds 900
        }
    }
    'False' {

        Invoke-Command @InvokeCommandParams
    }
}
