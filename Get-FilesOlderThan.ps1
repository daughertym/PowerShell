<#

.SYNOPSIS
Get files older than a specified number of days.

.PARAMETER Path
Specifies a path to a location.

.PARAMETER Include
Specifies, as a string array, an item or items that should be included.

.PARAMETER NumberOfDays
Specifies the number of days to set threshold to.

Settting NumberOfDays to 30 would find files older than 30 days.

.PARAMETER Recurse
Optional switch for recurse.

.PARAMETER CreationTime
Optional switch to filter by CreationTime rather than LastWriteTime.

.INPUTS
None. You cannot pipe objects.

.OUTPUTS
System.Object

.EXAMPLE
.\Get-FilesOlderThan -Path C:\SomePath\SomeFolder -NumberOfDays 30

.EXAMPLE
.\Get-FilesOlderThan -Path C:\SomePath\SomeFolder -NumberOfDays 30 -Recurse

.EXAMPLE
.\Get-FilesOlderThan -Path C:\SomePath\SomeFolder -NumberOfDays 30 -CreationTime

.EXAMPLE
.\Get-FilesOlderThan -Path C:\SomePath\SomeFolder -Include *.txt,*.pdf -NumberOfDays 30

.NOTES
Author: Matthew D. Daugherty
Date Modified: 30 July 2020

#>

[CmdletBinding()]
param (

    [Parameter(Mandatory)]
    [string]
    $Path,

    [Parameter()]
    [string[]]
    $Include,

    [Parameter(Mandatory)]
    [int]
    $NumberOfDays,

    [Parameter()]
    [switch]
    $Recurse,

    [Parameter()]
    [switch]
    $CreationTime
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

if ($PSBoundParameters.ContainsKey('Include')) {

    $gciParams.Add('Include',$Include)

    $gciParams.Path = "$Path\*"
}

if ($Recurse.IsPresent) {

    $gciParams.Add('Recurse',$true)
}

$Threshold = (Get-Date).AddDays(-$NumberOfDays)

if ($CreationTime.IsPresent) {

    Get-ChildItem @gciParams | Where-Object {$_.CreationTime -lt $Threshold}
}
else {

    Get-ChildItem @gciParams | Where-Object {$_.LastWriteTime -lt $Threshold}
}
