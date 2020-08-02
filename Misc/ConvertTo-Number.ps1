<#

Using the alphabet layout on phone, 
write a PowerShell function to convert a simple word to its numeric equivalent. 
For example, on a US phone, ‘help’ can be converted to 4357.

#>

[CmdletBinding()]
param (

    [Parameter(Mandatory)]
    [String]
    $Word
)

$Keypad = [ordered]@{

    2 = 'A','B','C'
    3 = 'D','E','F'
    4 = 'G','H','I'
    5 = 'J','K','L'
    6 = 'M','N','O'
    7 = 'P','Q','R','S'
    8 = 'T','U','V'
    9 = 'W','X','Y','Z'
}

$Letters = $Word.ToCharArray()

$Result = @()

foreach ($Letter in $Letters) {

    foreach ($Key in $Keypad.GetEnumerator()) {

        if ($Key.Value -contains $Letter) {

            $Result += $Key.Name
        }
    }
}

[PSCustomObject]@{

    Word = $Word
    Number = $Result -join ''
}
