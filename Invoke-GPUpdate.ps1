<#

.SYNOPSIS
Invoke gpupdate /force on one or more computers.

.PARAMETER ComputerName
Specifies the computer(s) to invoke gpupdate /force on.

.PARAMETER IncludeError
Optional switch to include errors.

.INPUTS
None.

.OUTPUTS
None.

.EXAMPLE
.\Invoke-GPUpdate -ComputerName PC01,PC02,PC03

.EXAMPLE
.\Invoke-GPUpdate -ComputerName (Get-Content C:\computers.txt)

.NOTES
Author: Matthew D. Daugherty
Date Modified: 21 July 2020

#>

[CmdletBinding()]
param (

    # Mandatory parameter for one or more computer names
    [Parameter(Mandatory)]
    [string[]]
    $ComputerName
)

begin {

    # Scriptblock for Invoke-Command
    $InvokeCommandScriptBlock = {
            
        Write-Verbose "Invoking gpupdate /force on $env:COMPUTERNAME" -Verbose

        gpupdate.exe /force /wait:0 | Out-Null

    } # end $InvokeCommandScriptBlock
}

process {

    # Parameters for Invoke-Command
    $InvokeCommandParams = @{

        ComputerName = $ComputerName
        ScriptBlock = $InvokeCommandScriptBlock
        ErrorAction = 'SilentlyContinue'
    }

    Invoke-Command @InvokeCommandParams
}

end {}
