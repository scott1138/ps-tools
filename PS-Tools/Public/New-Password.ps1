function New-Password {

    [CmdletBinding()]

    param (
        [ValidateRange(8,20)]
        [int] $PasswordLength = 12,

        [ValidateScript({$_ -le [Math]::Floor($PasswordLength/2)})]
        [int] $MinSpecialChars = 2
    )

    # !#$%&()*-.?@
    $punc = 33,35,36,37,38,40,41,42,45,46,63,64
    # 0-9
    $digits = 48..57
    # A-z
    $letters = 65..90 + 97..122

    do {
        $Password = (Get-Random -Count $PasswordLength -InputObject ($punc + $digits + $letters) | % {[char]$_}) -join ''
    }
    until ($Password -match "[0-9][A-z][!#$%&()*-.?@]{$MinSpecialChars}")

    return $Password

    <#
    .SYNOPSIS
        This function generates a complex password using numbers, upper and lower case letters, and from a list of special characters [!#$%&()*-.?@].
        The password can have a minimum of 8 characters with a maximum of 20.  The number of special charcters cannot exceed 1/2 of the total chacters.

    .PARAMETER PasswordLength
        This is the character length of the password.  The minimum number of characters is 8 and the maximum is 20. The default is 12.

    .PARAMETER MinSpecialCharacters
        This is the minimum number of special characters to include. This can be no more than half the total characters. The default is 2.
        NOTE: There may occassionally be more than the minimum, this is not an exact quantity match

    .EXAMPLE
        PS> New-Password

        This command will return a 12 character password with at least 2 special characters.

    .EXAMPLE
        PS> New-Password -PasswordLength 15 -MinSpecialCharacters 4

        This command will return a 15 character password with at least 4 special characters.

    .EXAMPLE
        PS> $SecurePassword = New-Password | ConvertTo-SecureString -AsPlainText -Force

        The output of this command can easily be converted to a secure string for use with other commands
        like New-ADUser or pscredential.

    #>

}