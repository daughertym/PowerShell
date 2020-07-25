<#

.SYNOPSIS
Create url shortcut on computers.

For example:

Create a url shortcut for www.reddit.com on Public Desktop.

.PARAMETER ComputerName
Specifies the computer(s) to create url shortcut on.

.PARAMETER Name
Specifies the name of the url shortcut.

.PARAMETER URL
Specifies the URL for the url shortcut.

.PARAMETER Destination
Specifies the destination for the url shortcut.

.PARAMETER IncludeError
Optional switch to include errors.

.INPUTS
None. You cannot pipe objects.

.OUTPUTS
System.Object

.EXAMPLE
New-URLShortcut -ComputerName PC01,PC02,PC03 -Name Reddit -URL www.reddit.com -Destination C:\Users\Public\Desktop

.EXAMPLE
New-URLShortcut (Get-Content C:\computers.txt) -Name Reddit -URL www.reddit.com -Destination C:\Users\Public\Desktop

.EXAMPLE
New-URLShortcut -ComputerName PC01,PC02,PC03 -Name Reddit -URL www.reddit.com -Destination C:\Users\Public\Desktop -IncludeError

.NOTES
Author: Matthew D. Daugherty
Date Modified: 25 July 2020

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
    $IncludeError
)


# Scriptblock for Invoke-Command
$InvokeCommandScriptBlock = {

    $VerbosePreference = $Using:VerbosePreference
    
    Write-Verbose "Creating $Using:URL shortcut on $env:COMPUTERNAME"

    $URLShortcutFile = "$($Using:Destination)\$($Using:Name).url"

    $WScriptShell = New-Object -ComObject WScript.Shell

    $URLShortcut = $WScriptShell.CreateShortcut($URLShortcutFile)

    $URLShortcut.TargetPath = $Using:URL

    $URLShortcut.Save()

    $Result = [PSCustomObject]@{

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
    ErrorAction = 'SilentlyContinue'
}

if ($IncludeError.IsPresent) {

    $InvokeCommandParams.Add('ErrorVariable','icmErrors')
}

Invoke-Command @InvokeCommandParams | ForEach-Object {

    [PSCustomObject]@{

        ComputerName = $_.PSComputerName.ToUpper()
        Name = $Name
        URL = $URL
        ShortcutCreated = $_.ShortcutCreated
        Error = $null
    }
}

if ($IncludeError.IsPresent) {

    if ($icmErrors) {

        foreach ($icmError in $icmErrors) {

            [PSCustomObject]@{

                ComputerName = $icmError.TargetObject.ToUpper()
                Name = $null
                URL = $null
                ShortcutCreated = $null
                Error = $icmError.FullyQualifiedErrorId
            }
        }
    }
}
