<#

    Remove certificates not belonging to you in the personal certificate store.

    Author: Matthew D. Daugherty
    Date Modified: 17 July 2020
#>

function Show-MessageBox {

    # Function to show message box

    param (

        # Mandatory parameter for message
        [Parameter(Mandatory)]
        [string]
        $Message,

        # Parameter for message box title
        [Parameter()]
        [string]
        $Title = $null,

        # Mandatory parameter for message box button
        [Parameter(Mandatory)]
        [ValidateSet('OK','OKCancel','YesNo','YesNoCancel')]
        [string]
        $Button,

        # Mandatory parameter for message box image
        [Parameter(Mandatory)]
        [ValidateSet(
            'Asterisk',
            'Error',
            'Exclamation',
            'Hand',
            'Information',
            'None',
            'Question',
            'Stop',
            'Warning'
        )]
        [string]
        $Image
    )

    Add-Type -AssemblyName PresentationCore,PresentationFramework
    [void][System.Windows.MessageBox]::Show($Message,$Title,$Button,$Image)
}

do {

    Clear-Host

    $LastName = Read-Host "`nEnter your last name"
    
} until ($LastName)

$LastName = $LastName.ToUpper()

# Make sure last name was entered correctly
if ($null -eq (Get-ChildItem -Path 'Cert:\CurrentUser\My\' | 
    Where-Object {$_.Subject -like "*$LastName*"})) {

    $ShowMessageBoxParams = @{

        Message = "Please verify the spelling of your last name and try again: $LastName"
        Title = 'Oops'
        Button = 'OK'
        Image = 'Information'
    }

    Show-MessageBox @ShowMessageBoxParams

    exit
}
# No certificates not belonging to $LastName exist
if ($null -eq (Get-ChildItem -Path 'Cert:\CurrentUser\My\' | 
    Where-Object {$_.Subject -notlike "*$LastName*"})) {

    $ShowMessageBoxParams = @{

        Message = 'There were no certificates not belonging to you to remove.'
        Title = 'Success'
        Button = 'OK'
        Image = 'Information'
    }

    Show-MessageBox @ShowMessageBoxParams
}
else {

    $ToRemove = Get-ChildItem -Path 'Cert:\CurrentUser\My\' | Where-Object {$_.Subject -notlike "*$LastName*"}

    $Num = $ToRemove.Count

    $ShowMessageBoxParams = @{

        Message = "$Num certificate(s) not belonging to you were removed."
        Title = 'Success'
        Button = 'OK'
        Image = 'Information'
    }

    Show-MessageBox @ShowMessageBoxParams

    $ToRemove | Remove-Item -Force
}
