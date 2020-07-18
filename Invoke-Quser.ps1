<#

.SYNOPSIS
Invoke quser.exe on one or more computers and return quser as an object.

Use to see which user is logged onto computer(s).

.PARAMETER ComputerName
Specifies the computer(s) to invoke quser.exe on.

.PARAMETER InvokeParallel
Optional switch to Invoke-Command in parallel.

.PARAMETER IncludeError
Optional switch to include errors with InvokeParallel.

.INPUTS
String

.OUTPUTS
System.Object

.EXAMPLE
.\Invoke-Quser -ComputerName PC01,PC02,PC03

.EXAMPLE
Invoke-Quser -ComputerName PC01,PC02,PC03 -IncludeError

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
        
        Write-Verbose "Invoking quser.exe on $env:COMPUTERNAME"
    
        function Convert-Quser {
    
            # Modified this function from Reddit user: litemage
        
            # Function to convert quser result into an object
        
            $Quser = quser.exe 2>$null
    
            if ($Quser) {
    
                foreach ($Line in $Quser) {
        
                    if ($Line -match "LOGON TIME") {continue}
                    
                    $IdleTimeValue = $Line.SubString(54, 9).Trim().Replace('+', '.')
            
                    If ($IdleTimeValue -eq 'none') {$Idle = $null}
                    
                    else {$Idle = [timespan]$IdleTimeValue}
                    
                    [PSCustomObject]@{
            
                        UserName =  $Line.SubString(1, 20).Trim()
                        SessionName = $Line.SubString(23, 17).Trim()
                        ID = $Line.SubString(42, 2).Trim()
                        State = $Line.SubString(46, 6).Trim()
                        IdleTime = $Idle
                        LogonTime = [datetime]$Line.SubString(65)
                    }
                }
            }
    
        } # end Convert-Quser
    
        $QuserObject = Convert-Quser
    
        if ($QuserObject) {
    
            foreach ($User in $QuserObject) {
    
                [PSCustomObject]@{
    
                    UserName = $User.UserName
                    State = $User.State
                    LogonTime = $User.LogonTime
                }
            }
        }
        else {
    
            [PSCustomObject]@{
    
                UserName = 'No user logged on'
                State = $null
                LogonTime = $null
            }
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
                    UserName = $null
                    State = $null
                    LogonTime = $null
                }

                if (Test-Connection -ComputerName $Computer -Count 1 -Quiet) {

                    $Result.TestConnection = $true

                    try {

                        $InvokeResult = Invoke-Command -ComputerName $Computer -ErrorAction Stop -ScriptBlock $InvokeCommandScriptBlock

                        foreach ($User in $InvokeResult) {

                            $Result.InvokeStatus = 'Success'

                            $Result.UserName = $User.UserName

                            $Result.State = $User.State

                            $Result.LogonTime = $User.LogonTime

                            $Result
                        }
                    }
                    catch {

                        $Result.InvokeStatus = $_.FullyQualifiedErrorId

                        $Result
                    }

                } # end (Test-Connection)
                else {

                    $Result
                }
        
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
                    UserName = $_.UserName
                    State = $_.State
                    LogonTime = $_.LogonTime
                }
            }

            if ($IncludeError.IsPresent) {

                if ($icmErrors) {
            
                    foreach ($icmError in $icmErrors) {
            
                        [PSCustomObject]@{
            
                            ComputerName = $icmError.TargetObject.ToUpper()
                            InvokeStatus = $icmError.FullyQualifiedErrorId
                            UserName = $null
                            State = $null
                            LogonTime = $null
                        }
                    }
            
                } # end if ($icmErrors)
            
            } # end if ($IncludeError.IsPresent)
        }

    } # end switch ($InvokeParallel.IsPresent)

} # end process

end {}
