<#

.SYNOPSIS
Get quser info from computers.

.PARAMETER ComputerName
Specifies the computers to query.

.PARAMETER IncludeNonResponding
Optional switch to include nonresponding computers.

.INPUTS
None. You cannot pipe objects.

.OUTPUTS
System.Object

.EXAMPLE
.\Get-Quser

.EXAMPLE
.\Get-Quser -ComputerName PC01,PC02,PC03

.EXAMPLE
.\Get-Quser (Get-Content C:\computers.txt) -ErrorAction SilentlyContinue

.EXAMPLE
.\Get-Quser (Get-Content C:\computers.txt) -IncludeNonResponding -Verbose | 
Export-Csv Users.csv -NoTypeInformation

.NOTES
Author: Matthew D. Daugherty
Date Modified: 2 August 2020

#>

[CmdletBinding()]
param (

    [Parameter()]
    [string[]]
    $ComputerName = $env:COMPUTERNAME,

    [Parameter()]
    [switch]
    $IncludeNonResponding
)

# Scriptblock for Invoke-Command
$InvokeCommandScriptBlock = {

    $VerbosePreference = $Using:VerbosePreference
    
    Write-Verbose "Getting quser info on $env:COMPUTERNAME."

    function Convert-Quser {

        # Modified this function from Reddit user: litemage
    
        # Function to convert quser result into an object
    
        $Quser = quser.exe 2>$null

        if ($Quser) {

            foreach ($Line in $Quser) {
    
                if ($Line -match "LOGON TIME") {continue}
                
                [PSCustomObject]@{
        
                    UserName =  $Line.SubString(1, 20).Trim()
                    State = $Line.SubString(46, 6).Trim()
                    LogonTime = [datetime]$Line.SubString(65)
                }
            }
        }

    } # end Convert-Quser

    $Result = [PSCustomObject]@{

        ComputerName = $env:COMPUTERNAME
        UserLoggedOn = $false
        UserName = $null
        State = $null
        LogonTime = $null
    }

    $QuserObject = Convert-Quser

    if ($QuserObject) {

        foreach ($User in $QuserObject) {

            $Result.UserLoggedOn = $true
            $Result.UserName = $User.UserName
            $Result.State = $User.State
            $Result.LogonTime = $User.LogonTime

            $Result
        }
    }
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
                    UserLoggedOn = $null
                    UserName = $null
                    State = $null
                    LogonTime = $null
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
