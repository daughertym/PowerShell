<#

.SYNOPSIS
Confirm if a certain hot fix is installed on one or more computers.

.PARAMETER ComputerName
Specifies the computer(s) to confirm hot fix on.

.PARAMETER ID
Specifies the hot fix ID to check for.

.PARAMETER InvokeParallel
Optional switch to Invoke-Command in parallel.

.PARAMETER IncludeError
Optional switch to include errors with InvokeParallel.

.INPUTS
String

.OUTPUTS
System.Object

.EXAMPLE
.\Confirm-HotFix (Get-Content C:\computers.txt) -ID KB4559309

.EXAMPLE
Get-Content C:\computers.txt | .\Confirm-HotFix -ID KB4559309

.EXAMPLE
.\Confirm-HotFix (Get-Content C:\computers.txt) -ID KB4559309 -InvokeParallel

.EXAMPLE
.\Confirm-HotFix (Get-Content C:\computers.txt) -ID KB4559309 -InvokeParallel -IncludeError

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

    # Mandatory parameter for hot fix ID
    [Parameter(Mandatory)]
    [string]
    $ID,

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

        Write-Verbose "Checking $env:COMPUTERNAME for hotfix ID $Using:ID"

        $Result = [PSCustomObject]@{

            Installed = $false
            InstalledOn = $null
        }

        $HotFix = Get-HotFix -ID $Using:ID -ErrorAction SilentlyContinue

        if ($HotFix) {

            $Result.Installed = $true

            $Result.InstalledOn = $HotFix.InstalledOn
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
                    HotFixID = $null
                    Installed = $null
                    InstalledOn = $null
                }

                if (Test-Connection -ComputerName $Computer -Count 1 -Quiet) {

                    $Result.TestConnection = $true

                    try {
                        
                        $InvokeResult = Invoke-Command -ComputerName $Computer -ErrorAction Stop -ScriptBlock $InvokeCommandScriptBlock

                        $Result.InvokeStatus = 'Success'

                        $Result.HotFixID = $ID

                        $Result.Installed = $InvokeResult.Installed

                        $Result.InstalledOn = $InvokeResult.InstalledOn
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
                    HotFixId = $ID
                    Installed = $_.Installed
                    InstalledOn = $_.InstalledOn
                }
            }

            if ($IncludeError.IsPresent) {

                if ($icmErrors) {
        
                    foreach ($icmError in $icmErrors) {
        
                        [PSCustomObject]@{
        
                            ComputerName = $icmError.TargetObject.ToUpper()
                            InvokeStatus = $icmError.FullyQualifiedErrorId
                            HotFixId = $null
                            Installed = $null
                            InstalledOn = $null
                        }
                    }
        
                } # end if ($icmErrors)
        
            } # end if ($IncludeError.IsPresent)
        }
        
    } # end switch ($InvokeParallel.IsPresent)

} # end process

end {}
