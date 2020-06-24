# Remove module and import the local version we want test
# This assumes the PSD1 file is two folders above this test file
Remove-Module PS-Tools -Force -ErrorAction SilentlyContinue
Import-Module "$PSScriptRoot\..\PS-Tools.psd1" -Force

Describe 'New-Password Tests' {
    It 'Generates the default password pattern and length' {
        $Password = New-Password
        $Password | Should -Match "[0-9][A-z][!#$%&()*-.?@]{2}"
        $Password.Length | Should -Be 12
    }

    It 'Generates a password of the requested length' {
        $Password = New-Password -PasswordLength 15
        $Password.Length | Should -Be 15
    }

    It 'Generates a password with the requested minimum number of special characters' {
        $Password = New-Password -PasswordLength 12 -MinSpecialChars 4
        $Password | Should -Match "[0-9][A-z][!#$%&()*-.?@]{4}"
    }
}