<#

.SYNOPSIS
Create url shortcut on one or more computers at a specified destination.

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

.PARAMETER InvokeParallel
Optional switch to Invoke-Command in parallel.

.PARAMETER IncludeError
Optional switch to include errors with InvokeParallel.

.INPUTS
String

.OUTPUTS
System.Object

.EXAMPLE
New-URLShortcut -ComputerName PC01,PC02,PC03 -Name Reddit -URL www.reddit.com -Destination C:\Users\Public\Desktop

.EXAMPLE
New-URLShortcut -ComputerName (Get-Content C:\computers.txt) -Name Reddit -URL www.reddit.com -Destination C:\Users\Public\Desktop

.EXAMPLE
Get-Content C:\computers.txt | New-URLShortcut -Name Reddit -URL www.reddit.com -Destination C:\Users\Public\Desktop

.EXAMPLE
New-URLShortcut -ComputerName PC01,PC02,PC03 -Name Reddit -URL www.reddit.com -Destination C:\Users\Public\Desktop -InvokeParallel

.EXAMPLE
New-URLShortcut -ComputerName PC01,PC02,PC03 -Name Reddit -URL www.reddit.com -Destination C:\Users\Public\Desktop -InvokeParallel -IncludeError

.NOTES
Author: Matthew D. Daugherty
Date Modified: 20 July 2020

#>


[CmdletBinding()]
param (

    # Mandatory parameter for one or more computer names
    [Parameter(Mandatory)]
    [string[]]
    $ComputerName,

    # Mandatory parameter for one or more computer names
    [Parameter(Mandatory)]
    [string]
    $Name,

    # Mandatory parameter for URL for shortcut
    [Parameter(Mandatory)]
    [string]
    $URL,

    # Mandatory parameter for destination for shortcut
    [Parameter(Mandatory)]
    [string]
    $Destination,

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
        
        Write-Verbose "Creating URL shortcut on $env:COMPUTERNAME"

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
                    Name = $null
                    URL = $null
                    ShortcutCreated = $null
                }

                if (Test-Connection -ComputerName $Computer -Count 1 -Quiet) {

                    $Result.TestConnection = $true

                    try {
                        
                        $InvokeResult = Invoke-Command -ComputerName $Computer -ErrorAction Stop -ScriptBlock $InvokeCommandScriptBlock

                        $Result.InvokeStatus = 'Success'

                        $Result.Name = $Name

                        $Result.URL = $URL

                        $Result.ShortcutCreated = $InvokeResult.ShortcutCreated
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
                    Name = $Name
                    URL = $URL
                    ShortcutCreated = $_.ShortcutCreated
                }
            }

            if ($IncludeError.IsPresent) {

                if ($icmErrors) {
        
                    foreach ($icmError in $icmErrors) {
            
                        [PSCustomObject]@{
            
                            ComputerName = $icmError.TargetObject.ToUpper()
                            InvokeStatus = $icmError.FullyQualifiedErrorId
                            Name = $null
                            URL = $null
                            ShortcutCreated = $null
                        }
                    }
        
                } # end if ($icmErrors)
        
            } # end if ($IncludeError.IsPresent)
        }

    } # end switch ($InvokeParallel.IsPresent)

} # end process

end {}
