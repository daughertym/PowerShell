<#

.SYNOPSIS
Get duplicate files.

.PARAMETER Path
Specifies a path to a location.

.PARAMETER Include
Specifies an item or items that should be included.

.PARAMETER ByName
Specifies that files will be queried by name.

.PARAMETER ByName
Specifies that files will be queried by hash.

.PARAMETER Recurse
Optional switch for recurse.

.INPUTS
None. You cannot pipe objects.

.OUTPUTS
System.Object

.EXAMPLE
.\Get-DuplicateFile -Path C:\SomePath\SomeFolder -ByName -Recurse

.EXAMPLE
.\Get-DuplicateFile -Path C:\SomePath\SomeFolder -ByHash -Recurse

.EXAMPLE
.\Get-DuplicateFile -Path C:\SomePath\SomeFolder -Include *.txt,*.ps1 -ByName -Recurse

.EXAMPLE
.\Get-DuplicateFile -Path C:\SomePath\SomeFolder -ByName | Select-Object Name,FullName |
Export-Csv DuplicateFiles.csv -NoTypeInformation

.NOTES
Author: Matthew D. Daugherty
Date Modified: 30 July 2020

#>

[CmdletBinding(DefaultParameterSetName = 'ByName')]

param (

    [Parameter()]
    [string]
    $Path,

    [Parameter()]
    [string[]]
    $Include,

    [Parameter(ParameterSetName = 'ByName')]
    [switch]
    $ByName,

    [Parameter(ParameterSetName = 'ByHash')]
    [switch]
    $ByHash,

    [Parameter()]
    [switch]
    $Recurse
)

$ErrorActionPreference = 'SilentlyContinue'

# Make sure $Path exists
if (-not(Test-Path -Path $Path)) {

    Write-Warning "Path: $Path does not exist."
    break
}

# Make sure $Path is a Directory
if (-not(Get-Item -Path $Path).PSIsContainer) {

    Write-Warning "Path: $Path is not a Directory."
    break
}

# Parameters for Get-ChildItem
$gciParams = @{

    Path = $Path
    File = $true
    Force = $true
}

if ($PSBoundParameters.ContainsKey('Include')) {

    $gciParams.Add('Include',$Include)

    $gciParams.Path = "$Path\*"
}

if ($Recurse.IsPresent) {

    $gciParams.Add('Recurse',$true)
}

if ($ByName.IsPresent) {

    $Files = Get-ChildItem @gciParams

    $Groups = $Files | Group-Object -Property Name

    $Groups | ForEach-Object {

        if ($_.Group.Count -gt 1) {
    
            $_.Group
        }
    }
}

if ($ByHash.IsPresent) {

    $Files = Get-ChildItem @gciParams | Get-FileHash

    $Groups = $Files | Group-Object -Property Hash

    $Groups | ForEach-Object {

        if ($_.Group.Count -gt 1) {
    
            Get-Item -Path ($_.Group).Path
        }
    }
}
