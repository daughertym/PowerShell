<#

.SYNOPSIS
Install SDC application on one or more computers.

.PARAMETER ComputerName
Specifies the computer(s) to install SDC application on.

.PARAMETER Path
Specifies path to folder containing SDC application files.
Default is /Desktop/SDCApps

.PARAMETER InvokeParallel
Optional switch to Invoke-Command in parallel.

.PARAMETER IncludeError
Optional switch to include errors with InvokeParallel.

.INPUTS
String

.OUTPUTS
System.Object

.EXAMPLE
.\Install-SDCApp -ComputerName PC01,PC02,PC03

.EXAMPLE
Get-Content C:\computers.txt | .\Install-SDCApp

.EXAMPLE
.\Install-SDCApp -ComputerName PC01,PC02,PC03 -InvokeParallel

.EXAMPLE
.\Install-Driver -ComputerName PC01,PC02,PC03 -InvokeParallel -IncludeError

.EXAMPLE
.\Install-Driver -ComputerName PC01,PC02,PC03 -SDCAppFolderPath C:\SDCApps -InvokeParallel -IncludeError

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
    $Path = "$env:USERPROFILE\Desktop\SDCApps",

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

    # If SDCAppFolderPath parameter is used
    if ($PSBoundParameters.ContainsKey('Path')) {

         # Make sure $SDCAppFolderPath exists
        if (-not(Test-Path -Path $Path)) {

            Write-Warning "Path: $Path does not exist."
            break
        }

        # Make sure $SDCAppFolderPath is a Directory
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

    $AppToInstall = (Get-ChildItem -Path $Path).Name | 
    Out-GridView -Title 'Select the SDC application to install' -OutputMode Single

    # If no SDC application is selected then break
    if (-not($AppToInstall)) {break}

    # Scriptblock for Invoke-Command
    $InvokeCommandScriptBlock = {

        $VerbosePreference = $Using:VerbosePreference
        
        Write-Verbose "Installing $Using:AppToInstall on $env:COMPUTERNAME"

        $Result = [PSCustomObject]@{

            Exists = $false
            InstallStatus = $null
        }

        if (Test-Path -Path "C:\Windows\Temp\$Using:AppToInstall\Install.cmd") {

            $Result.Exists = $true

            Start-Process -FilePath "C:\Windows\Temp\$Using:AppToInstall\Install.cmd" -Wait

            $Log = Get-ChildItem -Path 'C:\Windows\Logs\Software' | Sort-Object LastWriteTime |
            Select-Object -Last 1

            $LogContent = Get-Content -Path $Log.FullName -Last 3

            $Pattern = 'Installation completed(.*?)]'

            $ExitCode = ([regex]::Match($LogContent,$Pattern)).Value

            $Result.InstallStatus = $ExitCode

        } # end if (Test-Path)

        $Result

    } # end $InvokeCommandScriptBlock
}

process {

    foreach ($Computer in $ComputerName) {

        $Computer = $Computer.ToUpper()

        # Try to copy driver through C$
        try {

            $CopyItemParams = @{

                Path = "$Path\$AppToInstall"
                Destination = "\\$Computer\C$\Windows\Temp"
                Recurse = $true
                Force = $true
                ErrorAction = 'Stop'
            }

            Copy-Item @CopyItemParams

            Write-Verbose "SDC App ($AppToInstall) copied to $Computer" -Verbose
        }
         # Copy SDC App through session if C$ is not accessible
         catch {

            $Session = New-PSSession -ComputerName $Computer -ErrorAction SilentlyContinue

            if ($Session) {

                $CopyItemParams = @{

                    Path = "$Path\$SDCApp"
                    Destination = 'C:\Windows\Temp'
                    ToSession = $Session
                    Recurse = $true
                    Force = $true
                }

                Copy-Item @CopyItemParams

                Write-Verbose "SDC App ($SDCApp) copied to $Computer" -Verbose

                Remove-PSSession -Session $Session
            }
        }

    } # end foreach ($Computer in $ComputerName)

    Clear-Host

    switch ($InvokeParallel.IsPresent) {

        'False' {

            foreach ($Computer in $ComputerName) {

                $Result = [PSCustomObject]@{

                    ComputerName = $Computer.ToUpper()
                    TestConnection = $false
                    InvokeStatus = $null
                    SDCApp = $null
                    Exists = $null
                    InstallStatus = $null
                }

                if (Test-Connection -ComputerName $Computer -Count 1 -Quiet) {

                    $Result.TestConnection = $true

                    try {
                        
                        $InvokeResult = Invoke-Command -ComputerName $Computer -ErrorAction Stop -ScriptBlock $InvokeCommandScriptBlock

                        $Result.InvokeStatus = 'Success'

                        $Result.SDCApp = $AppToInstall

                        $Result.Exists = $InvokeResult.Exists

                        $Result.InstallStatus = $InvokeResult.InstallStatus
                    }
                    catch {

                        $Result.InvokeStatus = $_.FullyQualifiedErrorId
                    }
                    
                } # end if (Test-Connection)

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
                    SDCApp = $SDCApp
                    Exists = $_.Exists
                    InstallStatus = $_.InstallStatus
                }
            }

            if ($IncludeError.IsPresent) {

                if ($icmErrors) {
        
                    foreach ($icmError in $icmErrors) {
            
                        [PSCustomObject]@{
            
                            ComputerName = $icmError.TargetObject.ToUpper()
                            InvokeStatus = $icmError.FullyQualifiedErrorId
                            SDCApp = $null
                            Exists = $null
                            InstallStatus = $null
                        }
                    }
        
                } # end if ($icmErrors)

            } # end if ($IncludeError.IsPresent)
        }

    } # end switch ($InvokeParallel.IsPresent)

} # end process

end {}
