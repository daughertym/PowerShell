<#

    Select user(s) to log off on a remote computer.

    Author: Matthew D. Daugherty
    Date Modified: 17 June 2020
#>

do {

    Clear-Host

    $ComputerName = Read-Host "`nEnter computer name"
    
} until ($ComputerName)

$ComputerName = $ComputerName.ToUpper()

Clear-Host

function Convert-Quser {

    # Modified this function from Reddit user: litemage

    # Function to convert quser result into an object

    $Quser = quser.exe

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

if (Test-Connection -ComputerName $ComputerName -Count 1 -Quiet) {

    try {

        $Session = New-PSSession -ComputerName $ComputerName -ErrorAction Stop

        $LogOff = Invoke-Command -Session $Session -ScriptBlock ${Function:Convert-Quser} | 
        Out-GridView -Title 'Select user(s) to log off' -OutputMode Multiple
        
        if ($LogOff) {

            foreach ($UserName in $LogOff.UserName) {Out-Host -InputObject $UserName}

            $Title = 'Are you sure you want to log off the above user(s)?'
            $Prompt = $null
            $Choices = [System.Management.Automation.Host.ChoiceDescription[]] @('&Yes', '&No')
            $Default = 1
            $Choice = $host.UI.PromptForChoice($Title, $Prompt, $Choices, $Default)

            # If Yes
            if ($Choice -eq 0) {

                Invoke-Command -Session $Session -ScriptBlock {
    
                    foreach ($User in $Using:LogOff) {
                        
                        Write-Verbose "Logging off $($User.UserName)" -Verbose

                        logoff.exe $User.ID
                    }

                } # end Invoke-Command

            } # end if ($Choice)

        } # end if ($Logoff)

        Remove-PSSession -Session $Session
    }
    catch {Write-Warning "Failed to establish PowerShell session on $ComputerName"}
    
} # end if (Test-Connection)
else {Write-Warning "Test-Connection returned false on $ComputerName"}
