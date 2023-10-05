 <#
.SYNOPSIS
Get file version info from computers.

.PARAMETER ComputerName
Specifies the computers to query.

.PARAMETER FilePath
Specifies the file to query.

.PARAMETER IncludeNonResponding
Optional switch to include nonresponding computers.

.INPUTS
None. You cannot pipe objects.

.OUTPUTS
System.Object

.EXAMPLE
.\Get-FileVersion -ComputerName PC01,PC02,PC03 -FilePath 'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe'

.EXAMPLE
.\Get-FileVersion (Get-Content .\computers.txt) -FilePath 'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe' -ErrorAction SilentlyContinue

.EXAMPLE
.\Get-FileVersion (Get-Content .\computers.txt) -FilePath 'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe' -IncludeNonResponding -Verbose |
Export-Csv Chrome.csv -NoTypeInformation

.NOTES
Author: Matthew D. Daugherty
Date Modified: 27 July 2020

#>

[CmdletBinding()]
param (

    [Parameter(Mandatory)]
    [string[]]
    $ComputerName,

    [Parameter(Mandatory)]
    [string]
    $FilePath,

    [Parameter()]
    [switch]
    $IncludeNonResponding
)

$FilePath = $FilePath

# Script block for Invoke-Command
$InvokeCommandScriptBlock = {

    $VerbosePreference = $Using:VerbosePreference
    
    Write-Verbose "Querying $Using:FilePath on $env:COMPUTERNAME"

    $Result = [PSCustomObject]@{

        ComputerName = $env:COMPUTERNAME
        FilePath = $Using:FilePath
        FileExists = $false
        FileVersion = $null
        LastWriteTime = $null
    }

    if (Test-Path -Path $Using:FilePath) {

        $Result.FileExists = $true

        $File = Get-Item -Path $Using:FilePath

        $Result.FileVersion = $File.VersionInfo.FileVersionRaw

        $Result.LastWriteTime = $File.LastWriteTime
    }

    $Result
}

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

                [PSCustomObject]@{

                    ComputerName = $Computer.TargetObject.ToUpper()
                    FilePath = $null
                    FileExists = $null
                    FileVersion = $null
                    LastWriteTime = $null
                    ErrorId = $Computer.FullyQualifiedErrorId
                }
            }
        }
    }
    'False' {

        Invoke-Command @InvokeCommandParams | 
        Select-Object -Property * -ExcludeProperty PSComputerName, PSShowComputerName, RunspaceId
    }
}
