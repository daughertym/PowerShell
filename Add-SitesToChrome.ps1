<#
    Adds sites to Google Chrome's site data in Cookies and site data settings.

    Enables CVR Teams to work on USAF AFNet.

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

# Stop chrome process
Stop-Process -Name 'chrome' -ErrorAction SilentlyContinue

# The sites to be added
$Sites = @(

    '[*.]officeapps.live.com'
    '[*.]teams.microsoft.com',
    '[*.]microsoft.com',
    '[*.]microsoftonline.com',
    '[*.]api.gov.microsoftstream.com',
    '[*.]microsoftstream.com',
    '[*.]office.com',
    '[*.]office365.com',
    'sharepoint.com',
    '[*.]sharepoint.com',
    '[*.]svc.ms',
    '[*.]cdn.office.net',
    '[*.]usgovcloudapp.net',
    '[*.]windows.net',
    '[*.]teams.microsoft.us',
    '[*.]microsoft.us',
    'onenote.gcc.osi.office365.us',
    'pods.osi.office365.us',
    '[*.]osi.office365.us'
)

# The path to the preferences file
$File = "C:\Users\$env:USERNAME\AppData\Local\Google\Chrome\User Data\Default\Preferences"

# If the preferences file exists
if (Test-Path -Path $File) {

    $PreferencesFile = Get-Content -Path $File -Encoding UTF8 | ConvertFrom-Json

    $Setting = [PSCustomObject]@{

        last_modified = (Get-Date).ToFileTime()
        setting = 1
    }

    # Add each site to preferences file
    foreach ($Site in $Sites) {

        $PreferencesFile.profile.content_settings.exceptions.cookies |
        Add-Member -MemberType NoteProperty -Name "$($Site),*" -Value $Setting -Force
    }

    # Convert preferences file back to Json
    $PreferencesFile | ConvertTo-Json -Depth 100 -Compress | 
    Out-File "C:\Users\$env:USERNAME\AppData\Local\Google\Chrome\User Data\Default\Preferences" -Encoding UTF8

    $ShowMessageBoxParams = @{

        Message = 'Sites have been added to Google Chrome.'
        Button = 'OK'
        Image = 'Information'
    }

    Show-MessageBox @ShowMessageBoxParams
}
else {

    $ShowMessageBoxParams = @{

        Message = "$File does not exist."
        Button = 'OK'
        Image = 'Error'
    }

    Show-MessageBox @ShowMessageBoxParams
}
