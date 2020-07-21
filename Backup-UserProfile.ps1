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
Date Modified: 20 July 2020

#>

[CmdletBinding()]
param (

    # Mandatory parameter for computer name
    [Parameter(Mandatory)]
    [string]
    $ComputerName,

    # Parameter for user profile backup destination
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

$QuserScriptBlock = {

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
    else {

        [PSCustomObject]@{

            UserName = $null
        }
    }

} # end $QuserScriptBlock

if (Test-Connection -ComputerName $ComputerName -Count 1 -Quiet) {

    if (Test-Path -Path "\\$ComputerName\C$") {

        try {

            $Session = New-PSSession -ComputerName $ComputerName -ErrorAction Stop
            
            $UserProfile = Invoke-Command -Session $Session -ScriptBlock {
    
                (Get-ChildItem -Path 'C:\Users' | Sort-Object Name -Descending).Name
    
            } | Out-GridView -Title 'Select user profile to backup' -OutputMode Single
    
            if ($UserProfile) {
    
                $InvokeResult = Invoke-Command -Session $Session -ScriptBlock $QuserScriptBlock
    
                if ($InvokeResult.UserName -contains $UserProfile) {
    
                    Write-Warning "$UserProfile is currently logged onto $ComputerName. Script is ending."
                    break
    
                } # end if ($InvokeResult.UserName -contains $UserProfile)
                else {
    
                    $Backup = New-Item -Path $Destination -ItemType Directory -Name $UserProfile

                    $Backup = Split-Path -Path $Backup -NoQualifier
    
                    $Source = "\\$ComputerName\C$\Users\$UserProfile"

                    $Destination = "\\$env:COMPUTERNAME\c$\$Backup"

                    Robocopy.exe  $Source $Destination /S /XJD /XD 'AppData' /XF 'NTUSER.DAT' /R:0 /W:0 /MT:32

                    Invoke-Item -Path $Backup
                }
    
            } # end if ($UserProfile)
        }
        catch {
    
            Write-Warning "Failed to establish PowerShell session on $ComputerName with the following error: $($_.FullyQualifiedErrorID)"
        }

    } # end if (Test-Path -Path "\\$ComputerName\C$")
    else {

        Write-Warning "Test-Path of \\$ComputerName\C$ returned false." 
    }

} # end if (Test-Connection)
else {

    Write-Warning "Test-Connection on $ComputerName returned false."
}
