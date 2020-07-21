<#

.SYNOPSIS
Find computer(s) that a specific username has logged on to.

.PARAMETER ComputerName
Specifies the computer(s) to query.

.PARAMETER UserName
Specifies the username to find.

.PARAMETER InvokeParallel
Optional switch to Invoke-Command in parallel.

.PARAMETER IncludeError
Optional switch to include errors with InvokeParallel.

.INPUTS
String

.OUTPUTS
System.Object

.EXAMPLE
.\Find-UserProfile (Get-Content C:\computers.txt) -UserName 'UserName'

.EXAMPLE
Get-Content C:\computers.txt | .\Find-UserProfile -UserName 'UserName'

.EXAMPLE
.\Find-UserProfile (Get-Content C:\computers.txt) -UserName 'UserName' -InvokeParallel

.EXAMPLE
.\Find-UserProfile (Get-Content C:\computers.txt) -UserName 'UserName' -InvokeParallel -IncludeError

.NOTES
Author: Matthew D. Daugherty
Date Modified: 21 July 2020

#>

[CmdletBinding()]
param (

    # Mandatory parameter for one or more computer names
    [Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
    [string[]]
    $ComputerName,

    # Mandatory parameter for username to find
    [Parameter(Mandatory)]
    [string]
    $UserName,

    # Optional switch to Invoke-Command in parallel
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
        
        Write-Verbose "Checking for $Using:UserName on $env:COMPUTERNAME"

        $Result = [PSCustomObject]@{

            UserFound = $false
            LastWriteTime = $null
        }

        if (Test-Path -Path "C:\Users\$Using:UserName") {

            $Result.UserFound = $true

            $Result.LastWriteTime = (Get-Item -Path "C:\Users\$Using:UserName").LastWriteTime
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
                    UserName = $null
                    UserFound = $null
                    LastWriteTime = $null
                    Error = $null
                }

                if (Test-Connection -ComputerName $Computer -Count 1 -Quiet) {

                    $Result.TestConnection = $true

                    if (Test-Path -Path "\\$Computer\C$") {

                        if (Test-Path -Path "\\$Computer\C$\Users\$UserName") {

                            $Result.UserName = $UserName

                            $Result.UserFound = $true

                            $Result.LastWriteTime = (Get-Item -Path "\\$Computer\C$\Users\$UserName").LastWriteTime
                        }
                        else {

                            $Result.UserName = $UserName

                            $Result.UserFound = $false
                        }

                    } # end if (Test-Path -Path "\\$Computer\C$")
                    else {

                        try {

                            $InvokeCommandParams = @{

                                ComputerName = $Computer
                                ScriptBlock = $InvokeCommandScriptBlock
                                ErrorAction = 'Stop'
                            }

                            $InvokeResult = Invoke-Command @InvokeCommandParams

                            $Result.UserName = $UserName

                            $Result.UserFound = $InvokeResult.UserFound

                            $Result.LastWriteTime = $InvokeResult.LastWriteTime
                        }
                        catch {

                            $Result.Error = $_.FullyQualifiedErrorId
                        }

                    } # end else

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
                    UserName = $UserName
                    UserFound = $_.UserFound
                    LastWriteTime = $_.LastWriteTime
                }
            }

            if ($IncludeError.IsPresent) {

                if ($icmErrors) {
        
                    foreach ($icmError in $icmErrors) {
            
                        [PSCustomObject]@{
            
                            ComputerName = $icmError.TargetObject.ToUpper()
                            InvokeStatus = $icmError.FullyQualifiedErrorId
                            UserName = $null
                            UserFound = $null
                            LastWriteTime = $null
                        }
                    }
        
                } # end if ($icmErrors)
        
            } # end if ($PSBoundParameters)
        }

    } # end switch ($InvokeParallel.IsPresent)

} # end process

end {}
