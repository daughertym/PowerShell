<#

.SYNOPSIS
Backup a user profile from a remote computer.

.PARAMETER ComputerName
Specifies the computer to backup user profile from.

.PARAMETER Destination
Specifies backup destination.

Default is /Desktop/Backups

.INPUTS
None.

.OUTPUTS
None.

.EXAMPLE
.\Backup-UserProfile -ComputerName PC01

.EXAMPLE
.\Backup-UserProfile -ComputerName PC01 -Destination C:\Users\UserName\Desktop\MyBackups

.EXAMPLE
.\Backup-UserProfile -ComputerName PC01 -Destination \\ComputerName\C$\Users\UserName\Desktop\Backups

.NOTES
Author: Matthew D. Daugherty
Date Modified: 27 July 2020

#>

[CmdletBinding()]
param (

    [Parameter(Mandatory)]
    [string]
    $ComputerName,

    [Parameter()]
    [string]
    $Destination = "$env:USERPROFILE\Desktop\Backups"
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

    } | Out-GridView -Title 'Select user profile to backup' -OutputMode Single

    if ($ProfileToBackup) {

        $Quser = Invoke-Command -Session $Session -ErrorAction Stop -ScriptBlock $InvokeCommandScriptBlock

        if (-not($Quser.UserName -contains $ProfileToBackup)) {

            $BackupDirectory = New-Item -Path $Destination -ItemType Directory -Name $ProfileToBackup

            $BackupPath = Split-Path -Path $BackupDirectory -NoQualifier

            $Source = "\\$ComputerName\C$\Users\$ProfileToBackup"

            $Destination = "\\$env:COMPUTERNAME\c$\$BackupPath"

            Robocopy.exe  $Source $Destination /S /XJD /XD 'AppData' /XF 'NTUSER.DAT' /R:0 /W:0 /MT:16

            Invoke-Item -Path $BackupDirectory

        } # end if (-not($Quser.UserName -contains $ProfileToBackup))
        else {

            Write-Warning "$ProfileToBackup is currently logged onto $ComputerName. Script is ending."
        }

    } # end ($ProfileToBackup)

} # end if (Test-Path -Path "\\$ComputerName\C$")
else {

    Write-Warning "Test-Path of path \\$ComputerName\C$ returned False."
}
