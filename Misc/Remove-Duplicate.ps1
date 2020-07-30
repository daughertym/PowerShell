<#
    Useful for removing duplicate computer names in a text file.

    Example:
    .\Remove-Duplicate -Path C:\Users\UserName\Desktop\computers.txt

#>

[CmdletBinding()]
param (

    [Parameter(Mandatory)]
    [string]
    $Path
)

try {
    
    $FullName = (Get-Item -Path $Path -ErrorAction Stop).FullName

    $Unique = Get-Content -Path $Path | Sort-Object -Unique | Sort-Object

    Remove-Item -Path $FullName -Force

    Out-File -FilePath $FullName -InputObject $Unique
}
catch {

    Write-Warning $_   
}
