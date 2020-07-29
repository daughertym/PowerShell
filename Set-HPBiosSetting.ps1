<#

.SYNOPSIS
Set BIOS setting(s) on HP computer.

.INPUTS
None.

.OUTPUTS
None.

.EXAMPLE
.\Set-HPBiosSetting -ComputerName PC01

.NOTES
Author: Matthew D. Daugherty
Date Modified: 29 July 2020

#>

#Requires -RunAsAdministrator

[CmdletBinding()]
param (

    [Parameter(Mandatory)]
    [string]
    $ComputerName
)

try {

    $Session = New-PSSession -ComputerName $ComputerName -ErrorAction Stop

    $BiosSettings = Invoke-Command -Session $Session -ErrorAction Stop -ScriptBlock {

        Get-WmiObject -Namespace 'root\HP\InstrumentedBIOS' -Class 'HP_BiosEnumeration'
    }

    $SettingBios = $true

    do {

        $SettingToSet = $BiosSettings | Select-Object Name, CurrentValue |
        Out-GridView -Title 'Select a setting to set' -OutputMode Single

        if ($SettingToSet) {

            $SettingName = $SettingToSet.Name

            $CurrentValue = $SettingToSet.CurrentValue

            $NewValue = $BiosSettings | Where-Object Name -EQ $SettingName | 
            Select-Object -ExpandProperty PossibleValues |
            Out-GridView -Title "Setting: $SettingName | Current Value: $CurrentValue" -OutputMode Single

            if ($NewValue) {

                $PreviousValue = $CurrentValue

                $Invoke = Invoke-Command -Session $Session -ErrorAction Stop -ScriptBlock {

                    $BiosPassword = 'password'
                    $BiosPassword_UTF = "<utf-16/>$BiosPassword"
                    $Bios = Get-WmiObject -Namespace 'root\HP\InstrumentedBIOS' -Class 'HP_BiosSettingInterface'
                    $Bios.SetBiosSetting($Using:SettingName,$Using:NewValue,$BiosPassword_UTF)
                }

                switch ($Invoke.Return) {

                    0 {

                        [PSCustomObject]@{

                            SettingName = $SettingName
                            PreviousValue = $PreviousValue
                            NewValue = $NewValue
                            ReturnCode = $Invoke.Return
                            SuccessfullySet = $true
                        }
                    }
                    Default {

                        Write-Warning "$SettingName was not successfully set."

                        [PSCustomObject]@{

                            SettingName = $SettingName
                            PreviousValue = $PreviousValue
                            NewValue = $NewValue
                            ReturnCode = $Invoke.Return
                            SuccessfullySet = $false
                        }
                    }

                } # end switch ($Invoke.Return)

                $Title = 'Set another BIOS setting?'
                $Prompt = $null
                $Choices = [System.Management.Automation.Host.ChoiceDescription[]] @('&Yes', '&No')
                $Default = 1
                $Choice = $Host.UI.PromptForChoice($Title, $Prompt, $Choices, $Default)

                if ($Choice -eq 1) {

                    $SettingBios = $false
                }

            } # end if ($NewValue)
            else {exit}

        } # end if ($SettingToSet)
        else {exit}

    } while ($SettingBios)

    $Quser = Invoke-Command -Session $Session -ErrorAction Stop -ScriptBlock {

        quser.exe 2>$null
    }

    if ($null -eq $Quser) {

        Invoke-Command -Session $Session -ErrorAction Stop -ScriptBlock {

            Restart-Computer -Force
        }

        $WriteHostParams = @{

            Object = "No user was logged on. $($ComputerName.ToUpper()) was restarted for setting(s) to take effect."
            ForegroundColor = 'Yellow'
        }

        Write-Host @WriteHostParams
    }
    else {

        Write-Host "A restart is required for setting(s) to take effect." -ForegroundColor Yellow
    }

    Remove-Session -Session $Session
}
catch [System.Management.Automation.RemoteException] {

    Write-Warning "$($_): $($ComputerName.ToUpper()) may not be an HP computer."
}
catch {

    Write-Warning $_
}
