<#

    Locate .pst file(s) in current user profile.

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

Clear-Host

# Get .pst file(s) and store in variable Files
$Files = Get-ChildItem -Path $env:USERPROFILE -Recurse -Filter '*.pst'

# If .pst file(s) found
if ($Files) {

    # Number of .pst files found
    $Num = $Files.Count

    $ShowMessageParams = @{

        Message = "$Num .pst file(s) found."
        Button = 'OK'
        Image = 'Information'
    }
    
    Show-MessageBox @ShowMessageParams

    # Open each file location in File Explorer
    foreach ($File in $Files) {

        Invoke-Item -Path $File.Directory
    }
}
else {

    $ShowMessageParams = @{
        
        Message = 'No .pst file(s) found.'
        Button = 'OK'
        Image = 'Information'
    }

    Show-MessageBox @ShowMessageParams
}
