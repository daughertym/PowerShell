<#

.SYNOPSIS
Create url shortcut on computers.

For example:

Create a url shortcut for www.reddit.com on Public Desktop.

.PARAMETER ComputerName
Specifies the computers to create url shortcut on.

.PARAMETER Name
Specifies the name of the url shortcut.

.PARAMETER URL
Specifies the URL for the url shortcut.

.PARAMETER Destination
Specifies the destination for the url shortcut.

.PARAMETER IncludeNonResponding
Optional switch to include errors.

.INPUTS
None. You cannot pipe objects.

.OUTPUTS
System.Object

.EXAMPLE
New-URLShortcut -ComputerName PC01,PC02,PC03 -Name Reddit -URL www.reddit.com -Destination C:\Users\Public\Desktop

.EXAMPLE
New-URLShortcut (Get-Content C:\computers.txt) -Name Reddit -URL www.reddit.com -Destination C:\Users\Public\Desktop -ErrorAction SilentlyContinue 

.EXAMPLE
New-URLShortcut -ComputerName PC01,PC02,PC03 -Name Reddit -URL www.reddit.com -Destination C:\Users\Public\Desktop -IncludeNonResponding

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
    $Name,

    [Parameter(Mandatory)]
    [string]
    $URL,

    [Parameter(Mandatory)]
    [string]
    $Destination,

    [Parameter()]
    [switch]
    $IncludeNonResponding
)


# Scriptblock for Invoke-Command
$InvokeCommandScriptBlock = {

    $VerbosePreference = $Using:VerbosePreference
    
    Write-Verbose "Creating $Using:URL shortcut on $env:COMPUTERNAME."

    $URLShortcutFile = "$($Using:Destination)\$($Using:Name).url"

    $WScriptShell = New-Object -ComObject WScript.Shell

    $URLShortcut = $WScriptShell.CreateShortcut($URLShortcutFile)

    $URLShortcut.TargetPath = $Using:URL

    $URLShortcut.Save()

    $Result = [PSCustomObject]@{

        ComputerName = $env:COMPUTERNAME
        Name = $Using:Name
        URL = $Using:URL
        ShortcutCreated = $false
    }

    if (Test-Path -Path $URLShortcutFile) {

        $Result.ShortcutCreated = $true
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
                    Name = $null
                    URL = $null
                    ShortcutCreated = $null
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
