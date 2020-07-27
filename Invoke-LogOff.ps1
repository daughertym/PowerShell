<#

.SYNOPSIS
Log off user(s) from remote computer.

.PARAMETER ComputerName
Specifies the computer name to log off user(s) from.

.INPUTS
None. You cannot pipe objects.

.OUTPUTS
None.

.EXAMPLE
.\Invoke-LogOff -ComputerName PC01

.NOTES
Author: Matthew D. Daugherty
Date Modified: 27 July 2020

#>

[CmdletBinding()]
param (

    [Parameter(Mandatory)]
    [string]
    $ComputerName
)

function Convert-Quser {

    # Modified this function from Reddit user: litemage

    # Function to convert quser result into an object

    $Quser = quser.exe 2>$null

    if ($Quser) {

        foreach ($Line in $Quser) {

            if ($Line -match "LOGON TIME") {continue}
            
            [PSCustomObject]@{
    
                UserName =  $Line.SubString(1, 20).Trim()
                ID = $Line.SubString(42, 2).Trim()
                State = $Line.SubString(46, 6).Trim()
                LogonTime = [datetime]$Line.SubString(65)
            }
        }
    }
}

try {

    $Session = New-PSSession -ComputerName $ComputerName -ErrorAction Stop

    $Quser = Invoke-Command -Session $Session -ScriptBlock ${Function:Convert-Quser}

    if ($Quser) {

        $UserToLogOff = $Quser |
        Select-Object -Property * -ExcludeProperty PSComputerName, PSShowComputerName, RunspaceId |
        Out-GridView -Title 'Select user(s) to log off' -OutputMode Multiple

        if ($UserToLogOff) {

            foreach ($UserName in $UserToLogOff.UserName) {Write-Host $UserName -ForegroundColor Yellow}
    
            $Title = 'Are you sure you want to log off the above user(s)?'
            $Prompt = $null
            $Choices = [System.Management.Automation.Host.ChoiceDescription[]] @('&Yes', '&No')
            $Default = 1
            $Choice = $host.UI.PromptForChoice($Title, $Prompt, $Choices, $Default)
    
            if ($Choice -eq 0) {
    
                Invoke-Command -Session $Session -ScriptBlock {
        
                    foreach ($User in $Using:UserToLogOff) {
                        
                        Write-Verbose "Logging off $($User.UserName)." -Verbose
    
                        logoff.exe $User.ID
                    }
    
                }
            }
    
        } # end if ($UserToLogOff)

    } # end if ($Quser)
    else {

        Write-Output "[$($ComputerName.ToUpper())] There is no user logged on."
    }
}
catch {

    Write-Warning "[$($ComputerName.ToUpper())] Failed to establish PowerShell session."
}
