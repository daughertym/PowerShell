<#

.SYNOPSIS
Set .jpg image tags.

Before running script do the following:

$Images = 'C:\PathToYourImages'

Get-ChildItem -Path $Images | Select-Object FullName,Tags |
Export-Csv Tags.csv -NoTypeInformation

Open the exported csv file and add in the tags you want.
* No spaces between the tags

FullName                                         Tags
--------                                         ----
C:\Users\daughertym\Desktop\Images\Moon.jpg      Moon,Space
C:\Users\daughertym\Desktop\Images\Sunflower.jpg Sunflower,Summer

Save the csv file then run the script.

.PARAMETER CsvFilePath
Specifies the path to csv file containing tags.

.INPUTS
None. You cannot pipe objects.

.OUTPUTS
System.Object

.EXAMPLE 
.\Set-ImageTag -CsvFilePath .\Tags.csv

.EXAMPLE
.\Set-ImageTag -CsvFilePath .\Tags.csv -Verbose |
Export-Csv TagResults.csv -NoTypeInformation

.NOTES
Author: Matthew D. Daugherty
Date Modified: 30 July 2020

#>

#Requires -RunAsAdministrator

[CmdletBinding()]

param (

    [Parameter(Mandatory)]
    [string]
    $CsvFilePath
)

# If chocolately is NOT already installed then install it
if (-not(Test-Path -Path "$env:SystemDrive\ProgramData\chocolatey")) {

    Set-Location -Path "$env:SystemDrive\"

    # Install chocolatey
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072 
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

    # Install nuget.commandline with chocolately
    choco install nuget.commandline

    # Install required .dll file with NuGet
    NuGet.exe install Xpericode.JpegMetadata

    Clear-Host

    Write-Host "chocolately and Xpericode.JpegMetadata installed.`n" -ForegroundColor Green
    Pause
}

$GetChildItemParams = @{

    Path = "$env:SystemDrive\XperiCode*"
    Filter = 'XperiCode.JpegMetadata.dll'
    Recurse = $true
    Force = $true
    ErrorAction = 'SilentlyContinue'
}

# Get the required .dll file
$dllFile = (Get-ChildItem @GetChildItemParams).FullName
    
if ($dllFile) {

    # Add the required .dll file
    Add-Type -Path $dllFile
        
    # Import csv file containing Tags
    $CsvFile = Import-Csv -Path $CsvFilePath -ErrorAction Stop

    foreach ($Row in $CsvFile) {

        $ImageName = Split-Path -Path $Row.FullName -Leaf

        if ($Row.FullName -notlike '*.jpg') {

            Write-Warning "$($Row.FullName) is not a .jpg file."

            Continue
        }

        foreach ($Tag in $Row.Tags -split ',') {

            $ImageObject = New-Object XperiCode.JpegMetadata.JpegMetadataAdapter($Row.FullName)

            $Result = [PSCustomObject]@{

                Image = $Row.FullName
                Tag = $Tag
                Added = $false
            }

            $ImageObject.Metadata.Keywords.Add($Tag)

            [void]$ImageObject.Save()

            $ImageObject = New-Object XperiCode.JpegMetadata.JpegMetadataAdapter($Row.FullName)

            if ($ImageObject.Metadata.Keywords -contains $Tag) {

                Write-Verbose "Successfully added Tag:$Tag to Image:$ImageName."

                $Result.Added = $true
            }
            else {

                Write-Warning "Tag:$Tag was not added to Image:$ImageName."
            }
        
            $Result

        } # end foreach ($Tag in $Row.Tags -split ',')

    } # end foreach ($Row in $CsvFile)

} # end if ($dllFile)
else {

    Write-Warning "The required .dll file was not found."
}
