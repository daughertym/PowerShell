<#

.SYNOPSIS
Install driver(s) on one or more computers.

.PARAMETER ComputerName
Specifies the computer(s) to install driver(s) on.

.PARAMETER Path
Specifies path to folder containing driver(s).
Default is /Desktop/Drivers

.PARAMETER InvokeParallel
Optional switch to Invoke-Command in parallel.

.PARAMETER IncludeError
Optional switch to include errors with InvokeParallel.

.INPUTS
String

.OUTPUTS
System.Object

.EXAMPLE
.\Install-Driver -ComputerName PC01,PC02,PC03

.EXAMPLE
Get-Content C:\computers.txt | .\Install-Driver

.EXAMPLE
.\Install-Driver -ComputerName PC01,PC02,PC03 -InvokeParallel

.EXAMPLE
.\Install-Driver -ComputerName PC01,PC02,PC03 -InvokeParallel -IncludeError

.EXAMPLE
.\Install-Driver -ComputerName PC01,PC02,PC03 -Path C:\Drivers -InvokeParallel -IncludeError

.NOTES
Author: Matthew D. Daugherty
Date Modified: 20 July 2020

#>

[CmdletBinding()]
param (

    # Mandatory parameter for one or more computer names
    [Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
    [string[]]
    $ComputerName,

    # Parameter for path to folder containing driver(s)
    [Parameter()]
    [string]
    $Path = "$env:USERPROFILE\Desktop\Drivers",

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

    # If DriverFolderPath parameter is used
    if ($PSBoundParameters.ContainsKey('Path')) {

        # Make sure $DriverFolderPath exists
        if (-not(Test-Path -Path $Path)) {

            Write-Warning "Path: $Path does not exist."
            break
        }

        # Make sure $DriverFolderPath is a Directory
        if (-not(Get-Item -Path $Path).PSIsContainer) {

            Write-Warning "Path: $Path is not a Directory."
            break
        }
    }

    # Make sure InvokeParallel switch is not being used with piping input
    if ($InvokeParallel.IsPresent -and $MyInvocation.ExpectingInput) {

        Write-Warning 'Cannot accept pipeline input while using the InvokeParallel switch.'
        break
    }

    # Make sure Invoke-Parallel switch is not being used with only one computer name
    if ($ComputerName.Count -eq 1 -and $InvokeParallel.IsPresent) {

        Write-Warning 'The InvokeParallel switch cannot be used with only one computer name.'
        break
    }

    $DriverToInstall = (Get-ChildItem -Path $Path).Name | 
    Out-GridView -Title 'Select driver(s) to install' -OutputMode Multiple

    # If no driver(s) selected then break
    if (-not($DriverToInstall)) {break}

    # Scriptblock for Invoke-Command
    $InvokeCommandScriptBlock = {

        $VerbosePreference = $Using:VerbosePreference
        
        Write-Verbose "Installing driver(s) on $env:COMPUTERNAME"

        $Result = New-Object -TypeName psobject

        foreach ($Driver in $Using:DriverToInstall) {

            $Result | Add-Member -NotePropertyName $Driver -NotePropertyValue $null

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
}

process {

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

    switch ($InvokeParallel.IsPresent) {

        'False' {

            foreach ($Computer in $ComputerName) {

                $Result = [PSCustomObject]@{

                    ComputerName = $Computer.ToUpper()
                    TestConnection = $false
                    InvokeStatus = $null
                }

                foreach ($Driver in $DriverToInstall) {

                    $Result | Add-Member -MemberType NoteProperty -Name $Driver -Value $null
                }

                if (Test-Connection -ComputerName $Computer -Count 1 -Quiet) {

                    $Result.TestConnection = $true

                    try {
                        
                        $InvokeResult = Invoke-Command -ComputerName $Computer -ErrorAction Stop -ScriptBlock $InvokeCommandScriptBlock

                        $Result.InvokeStatus = 'Success'

                        foreach ($Item in $InvokeResult) {

                            foreach ($Driver in $DriverToInstall) {

                                $Result | Add-Member -MemberType NoteProperty -Name $Driver -Value $Item.$Driver -Force
                            }
                        }
                    }
                    catch {

                        $Result.InvokeStatus = $_.FullyQualifiedErrorId
                    }

                } # end if (Test-Connection)

                $Result

            } # end foreach ($Computer in $Computers)
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

                $Result = [PSCustomObject]@{
        
                    ComputerName = $_.PSComputerName.ToUpper()
                    InvokeStatus = 'Success'
                }
        
                foreach ($Driver in $DriverToInstall) {
        
                    $Result | Add-Member -MemberType NoteProperty -Name $Driver -Value $_.$Driver
                }
        
                $Result
            }

            if ($IncludeError.IsPresent) {

                if ($icmErrors) {
        
                    foreach ($icmError in $icmErrors) {
            
                        $Result = [PSCustomObject]@{
            
                            ComputerName = $icmError.TargetObject.ToUpper()
                            InvokeStatus = $icmError.FullyQualifiedErrorId
                        }
        
                        foreach ($Driver in $DriverToInstall) {
        
                            $Result | Add-Member -MemberType NoteProperty -Name $Driver -Value $null
                        }
        
                        $Result
                    }
        
                } # end if ($icmErrors)
        
            } # end if ($IncludeError.IsPresent)
        }

    } # end switch ($InvokeParallel.IsPresent)

} # end process

end {}
