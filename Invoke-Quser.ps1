<#

.SYNOPSIS
Invoke quser.exe on computers and get result as object.

.PARAMETER ComputerName
Specifies the computers to query.

.PARAMETER IncludeError
Optional switch to include errors.

.INPUTS
None. You cannot pipe objects.

.OUTPUTS
System.Object

.EXAMPLE
.\Invoke-Quser -ComputerName PC01,PC02,PC03

.EXAMPLE
.\Invoke-Quser (Get-Content C:\computers.txt) -IncludeError

.EXAMPLE
.\Invoke-Quser (Get-Content C:\computers.txt) -Verbose | 
Export-Csv Users.csv -NoTypeInformation

.NOTES
Author: Matthew D. Daugherty
Date Modified: 25 July 2020

#>

[CmdletBinding()]
param (

    [Parameter(Mandatory)]
    [string[]]
    $ComputerName,

    [Parameter()]
    [switch]
    $IncludeError
)

# Scriptblock for Invoke-Command
$InvokeCommandScriptBlock = {

    $VerbosePreference = $Using:VerbosePreference
    
    Write-Verbose "Invoking quser.exe on $env:COMPUTERNAME"

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

    $QuserObject = Convert-Quser

    if ($QuserObject) {

        foreach ($User in $QuserObject) {

            [PSCustomObject]@{

                UserLoggedOn = $true
                UserName = $User.UserName
                State = $User.State
                LogonTime = $User.LogonTime
            }
        }
    }
    else {

        [PSCustomObject]@{

            $UserLoggedOn = $false
            UserName = $null
            State = $null
            LogonTime = $null
        }
    }
} 

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
        UserLoggedOn = $_.UserLoggedOn
        UserName = $_.UserName
        State = $_.State
        LogonTime = $_.LogonTime
        Error = $null
    }
}

if ($IncludeError.IsPresent) {

    if ($icmErrors) {

        foreach ($icmError in $icmErrors) {

            [PSCustomObject]@{

                ComputerName = $icmError.TargetObject.ToUpper()
                UserLoggedOn = $null
                UserName = $null
                State = $null
                LogonTime = $null
                Error = $icmError.FullyQualifiedErrorId
            }
        }
    }
}
