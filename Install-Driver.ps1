<#

.SYNOPSIS
Install driver(s) on computers.

.PARAMETER ComputerName
Specifies the computer(s) to install drivers on.

.PARAMETER Path
Specifies path to folder containing driver(s).
Default is /Desktop/Drivers

Create a folder on Desktop named Drivers.

Inside Drivers folder create subfolders for your driver(s).

    HP
    Konica Minolta
    Lexmark
    Xerox

Put driver files in their respective folders.

.PARAMETER IncludeError
Optional switch to include errors.

.INPUTS
None. You cannot pipe objects.

.OUTPUTS
System.Object

.EXAMPLE
.\Install-Driver -ComputerName PC01,PC02,PC03

.EXAMPLE
.\Install-Driver -ComputerName PC01,PC02,PC03 -Path C:\Drivers

.EXAMPLE
.\Install-Driver (Get-Content C:\computers.txt) -IncludeNonResponding -ErrorAction SilentlyContinue

.NOTES
Author: Matthew D. Daugherty
Date Modified: 27 July 2020

#>

[CmdletBinding()]
param (

    [Parameter(Mandatory)]
    [string[]]
    $ComputerName,

    [Parameter()]
    [string]
    $Path = "$env:USERPROFILE\Desktop\Drivers",

    [Parameter()]
    [switch]
    $IncludeNonResponding
)

if (-not(Test-Path -Path $Path)) {

    Write-Warning "Path: $Path does not exist."
    break
}

if (-not(Get-Item -Path $Path).PSIsContainer) {

    Write-Warning "Path: $Path is not a Directory."
    break
}

$DriverToInstall = (Get-ChildItem -Path $Path).Name | 
Out-GridView -Title 'Select driver(s) to install' -OutputMode Multiple

if ($DriverToInstall) {

    # Scriptblock for Invoke-Command
    $InvokeCommandScriptBlock = {

        $VerbosePreference = $Using:VerbosePreference
        
        Write-Verbose "Installing driver(s) on $env:COMPUTERNAME."

        $Result = [PSCustomObject]@{

            ComputerName = $env:COMPUTERNAME
        }

        foreach ($Driver in $Using:DriverToInstall) {

            $Result | Add-Member -MemberType NoteProperty -Name $Driver -Value $null

            if (Test-Path -Path "C:\Windows\Temp\$Driver") {

                $inf_Files = Get-ChildItem -Path "C:\Windows\Temp\$Driver" -Recurse -Filter '*.inf'

                $Failed = @()

                foreach ($inf in $inf_Files) {
        
                    $Install = pnputil.exe /add-driver $inf.FullName /install

                    if ($Install -like '*Failed*') {

                        $Failed += $inf
                    }
                }

                if ($Failed) {

                    if ($Failed.Count -gt 1) {

                        $Failed = $Failed -split ', '

                        $Result.$Driver = "Failed to install: $Failed"
                    }
                    else {$Result.$Driver = "Failed to install $Failed"}
                }
                else {$Result.$Driver = 'Installed Successfully'}

            } # end if (Test-Path)
            else {$Result.$Driver = 'Does not exist'}

        } # end foreach ($Driver in $Using:DriverToInstall)

        $Result

    } # end $InvokeCommandScriptBlock

    $Counter = 0

    foreach ($Computer in $ComputerName) {

        $Computer = $Computer.ToUpper()

        $Counter++

        $WriteProgressParams = @{

            Activity = 'Copying driver(s)'
            Status = "Computer $Counter of $($ComputerName.Count)"
            CurrentOperation = "$Computer"
            PercentComplete = (($Counter / $ComputerName.Count) * 100)
        }

        Write-Progress @WriteProgressParams

        foreach ($Driver in $DriverToInstall) {

            # Try to copy driver through C$
            try {

                $CopyItemParams = @{

                    Path = "$Path\$Driver"
                    Destination = "\\$Computer\C$\Windows\Temp"
                    Recurse = $true
                    Force = $true
                    ErrorAction = 'Stop'
                }

                Copy-Item @CopyItemParams
            }
            # Copy driver through session if C$ is not accessible
            catch {

                $Session = New-PSSession -ComputerName $Computer -ErrorAction SilentlyContinue

                if ($Session) {

                    $CopyItemParams = @{

                        Path = "$Path\$Driver"
                        Destination = 'C:\Windows\Temp'
                        ToSession = $Session
                        Recurse = $true
                        Force = $true
                    }

                    Copy-Item @CopyItemParams

                    Remove-PSSession -Session $Session
                }
            }

        } # end foreach ($Driver in $DriverToInstall)

    } # end (foreach $Computer in $ComputerName)

    Write-Progress -Activity 'Copying driver(s)' -Completed

    # Parameters for Invoke-Command
    $InvokeCommandParams = @{

        ComputerName = $ComputerName
        ScriptBlock = $InvokeCommandScriptBlock
        ErrorAction = $ErrorActionPreference
    }

    switch ($IncludeNonResponding.IsPresent) {

        'True' {

            $InvokeCommandParams.Add('ErrorVariable','NonResponding')

            Invoke-Command @InvokeCommandParams | 
            Select-Object -Property *, ErrorId -ExcludeProperty PSComputerName, PSShowComputerName, RunspaceId

            if ($NonResponding) {

                foreach ($Computer in $NonResponding) {
    
                    $Result = [PSCustomObject]@{
    
                        ComputerName = $Computer.TargetObject.ToUpper()
                    }

                    foreach ($Driver in $DriverToInstall) {

                        $Result | Add-Member -MemberType NoteProperty -Name $Driver -Value $null
                    }
    
                    $Result | Add-Member -MemberType NoteProperty -Name 'ErrorID' -Value $Computer.FullyQualifiedErrorId
    
                    $Result
                }
            }
        }
        'False' {

            Invoke-Command @InvokeCommandParams | 
            Select-Object -Property * -ExcludeProperty PSComputerName, PSShowComputerName, RunspaceId
        }
    }

} # end if ($DriverToInstall)
