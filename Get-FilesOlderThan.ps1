<#

.SYNOPSIS
Get files older than a specified number of days.

.PARAMETER Path
Specifies the path to the folder to query.

.PARAMETER Include
Specifies the file type(s) to include.

.PARAMETER NumberOfDays
Specifies the number of days to set threshold to.

Settting NumberOfDays to 30 would find files older than 30 days.

.PARAMETER Recurse
Optional switch for recurse.

.INPUTS
None. You cannot pipe objects to Get-FilesOlderThan

.OUTPUTS
System.Object

.EXAMPLE
.\Get-FilesOlderThan -Path C:\SomePath\SomeFolder -NumberOfDays 30

.EXAMPLE
.\Get-FilesOlderThan -Path C:\SomePath\SomeFolder -NumberOfDays 30 -Recurse

.EXAMPLE
.\Get-FilesOlderThan -Path C:\SomePath\SomeFolder -Include *.txt,*.pdf -NumberOfDays 30

.NOTES
Author: Matthew D. Daugherty
Date Modified: 17 July 2020

#>

[CmdletBinding()]
param (

    # Mandatory parameter for path
    [Parameter(Mandatory)]
    [string]
    $Path,

    # Optional paramater to include certain file type(s)
    [Parameter()]
    [string[]]
    $Include,

    # Mandatory parameter for number of days
    [Parameter(Mandatory)]
    [int]
    $NumberOfDays,

    # Optional switch for recurse
    [Parameter()]
    [switch]
    $Recurse
)

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

if ($Include.IsPresent) {

    $gciParams.Add('Include',$Include)

    $gciParams.Path = "$Path\*"
}

if ($Recurse.IsPresent) {

    $gciParams.Add('Recurse',$true)
}

$Threshold = (Get-Date).AddDays(-$NumberOfDays)

Get-ChildItem @gciParams |
Where-Object {$_.LastWriteTime -lt $Threshold}
