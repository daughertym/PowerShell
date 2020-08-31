<#

.SYNOPSIS
Backup user profile(s).

.PARAMETER ComputerName
Specifies the computer to backup user profile(s) from.

.PARAMETER Destination
Specifies backup destination.

Default is /Desktop/UserProfile Backups

.INPUTS
None.

.OUTPUTS
None.

.EXAMPLE
.\Backup-UserProfile -ComputerName PC01 -Destination \\ComputerName\C$\UserName\Desktop\Backups

.NOTES
Author: Matthew D. Daugherty
Date Modified: 31 August 2020

#>

[CmdletBinding()]
param (

    [Parameter()]
    [string]
    $ComputerName = $env:COMPUTERNAME,

    [Parameter()]
    [string]
    $Destination = "$env:USERPROFILE\Desktop\UserProfile Backups"
)

$ComputerName = $ComputerName.ToUpper()

if (-not(Test-Path -Path $Destination)) {

    try {

        New-Item -Path $Destination -ItemType Directory -ErrorAction Stop | Out-Null
    }
    catch {

        Write-Warning "Failed to create directory at path: $Destination"
        break
    }
}

# Scriptblock for Invoke-Command
$InvokeCommandScriptBlock = {

    function Convert-Quser {

        # Modified this function from Reddit user: litemage
    
        # Function to convert quser result into an object
    
        $Quser = quser.exe 2>$null

        if ($Quser) {

            foreach ($Line in $Quser) {
    
                if ($Line -match "LOGON TIME") {continue}
                
                [PSCustomObject]@{
        
                    UserName =  $Line.SubString(1, 20).Trim()
                }
            }
        }

    } # end Convert-Quser

    $QuserObject = Convert-Quser

    if ($QuserObject) {

        foreach ($User in $QuserObject) {

            [PSCustomObject]@{

                UserName = $User.UserName
            }
        }
    }
}

Test-Connection -ComputerName $ComputerName -Count 1 -ErrorAction Stop | Out-Null

if (Test-Path -Path "\\$ComputerName\C$") {

    $Session = New-PSSession -ComputerName $ComputerName -ErrorAction Stop

    $ProfileToBackup = Invoke-Command -Session $Session -ScriptBlock {

        (Get-ChildItem -Path 'C:\Users' | Sort-Object Name -Descending).Name

    } | Out-GridView -Title 'Select user profile to backup' -OutputMode Multiple

    if ($ProfileToBackup) {

        $Quser = Invoke-Command -Session $Session -ErrorAction Stop -ScriptBlock $InvokeCommandScriptBlock

        foreach ($User in $ProfileToBackup) {

            if (-not($Quser.UserName -contains $User)) {

                if (-not(Test-Path -Path "$Destination\$User")) {

                    $BackupDirectory = New-Item -Path $Destination -ItemType Directory -Name $User
    
                    $BackupPath = Split-Path -Path $BackupDirectory -NoQualifier
                }
                else {

                    $BackupDirectory = (Get-ChildItem -Path $Destination | Where-Object Name -EQ $User).FullName

                    $BackupPath = Split-Path -Path $BackupDirectory -NoQualifier
                }

                $Source = "\\$ComputerName\C$\Users\$User"
    
                $Destination = "\\$env:COMPUTERNAME\c$\$BackupPath"
    
                Robocopy.exe  $Source $Destination /S /XJD /XD 'AppData' /XF 'NTUSER.DAT' /R:0 /W:0 /MT:16
    
                Invoke-Item -Path $BackupDirectory
    
            } # end if (-not($Quser.UserName -contains $ProfileToBackup))
            else {
    
                Write-Warning "$User is currently logged onto $ComputerName. Script is ending."
            }

        } # end foreach ($User in $ProfileToBackup)

    } # end ($ProfileToBackup)

} # end if (Test-Path -Path "\\$ComputerName\C$")
else {

    Write-Warning "Test-Path of path \\$ComputerName\C$ returned False."
}
