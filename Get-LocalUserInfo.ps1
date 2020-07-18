<#

.SYNOPSIS
Get local user account info from one or more computers.

.PARAMETER ComputerName
Specifies the computer(s) to get local user account info from.

.PARAMETER InvokeParallel
Optional switch to Invoke-Command in parallel.

.PARAMETER IncludeError
Optional switch to include errors with InvokeParallel.

.INPUTS
String

.OUTPUTS
System.Object

.EXAMPLE
.\Get-LocalUserInfo (Get-Content .\computers.txt)

.EXAMPLE
Get-Content .\computers.txt | .\Get-LocalUserInfo -FilePath

.EXAMPLE
.\Get-FileVersion (Get-Content .\computers.txt) -InvokeParallel

.EXAMPLE
.\Get-FileVersion (Get-Content .\computers.txt) -InvokeParallel -IncludeError

.NOTES
Author: Matthew D. Daugherty
Date Modified: 17 July 2020

#>

[CmdletBinding()]
param (

    # Parameter for one or more computer names
    [Parameter(ValueFromPipeline,ValueFromPipelineByPropertyName)]
    [string[]]
    $ComputerName = $env:COMPUTERNAME,

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
        
        Write-Verbose "Getting local user info on $env:COMPUTERNAME"
    
        $ResultsArray = @()
    
        foreach ($LocalUser in Get-LocalUser) {
    
            $LocalUserInfo = [PSCustomObject]@{
    
                LocalUser = $LocalUser.Name
                LastLogon = $LocalUser.LastLogon
                Enabled = $LocalUser.Enabled
                GroupMembership = $null
            }
    
            $GroupArray = @()
    
            foreach ($Group in Get-LocalGroup) {
        
                # If local user is a member of the current group in loop
                if (Get-LocalGroupMember -Name $Group -Member $LocalUser -ErrorAction SilentlyContinue) {
    
                    # Add the name of the group to $GroupArray
                    $GroupArray += $Group.Name 
                }
            }
    
            $GroupMembership = $GroupArray -join ", "
    
            $LocalUserInfo.GroupMembership = $GroupMembership
    
            $ResultsArray += $LocalUserInfo
        }
    
        $ResultsArray
    
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
                    LocalUser = $null
                    LastLogon = $null
                    Enabled = $null
                    GroupMembership = $null
                }
        
                if (Test-Connection -ComputerName $Computer -Count 1 -Quiet) {
        
                    $Result.TestConnection = $true
        
                    try {
        
                        $InvokeResult = Invoke-Command -ComputerName $Computer -ErrorAction Stop -ScriptBlock $InvokeCommandScriptBlock
        
                        $InvokeResult | ForEach-Object {
        
                            $Result.InvokeStatus = 'Success'
        
                            $Result.LocalUser = $_.LocalUser
        
                            $Result.LastLogon = $_.LastLogon
        
                            $Result.Enabled = $_.Enabled
        
                            $Result.GroupMembership = $_.GroupMembership
        
                            $Result
                        }
                    }
                    catch {
        
                        $Result.InvokeStatus = $_.FullyQualifiedErrorId
        
                        $Result
                    }
        
                } # end if (Test-Connection)
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
                    LocalUser = $_.LocalUser
                    LastLogon = $_.LastLogon
                    Enabled = $_.Enabled
                    GroupMembership = $_.GroupMembership
                }
            }

            if ($IncludeError.IsPresent) {

                if ($icmErrors) {
            
                    foreach ($icmError in $icmErrors) {
            
                        [PSCustomObject]@{
            
                            ComputerName = $icmError.TargetObject.ToUpper()
                            InvokeStatus = $icmError.FullyQualifiedErrorId
                            LocalUser = $null
                            LastLogon = $null
                            Enabled = $null
                            GroupMembership = $null
                        }
                    }
            
                } # end if ($icmErrors)
            
            } # end if ($IncludeError.IsPresent)
        }

    } # end switch ($InvokeParallel.IsPresent)

} # end process

end {}
