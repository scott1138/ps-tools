# Remove module and import the local version we want test
# This assumes the PSD1 file is two folders above this test file
# 4>$null send the requires warnings to null to cut down on the 
Remove-Module PS-Tools -Force -ErrorAction SilentlyContinue -Verbose:$false
Import-Module "$PSScriptRoot\..\PS-Tools.psd1" -Force -DisableNameChecking 4>$null

Describe 'Get-EmailTemplate Tests' {

    It 'Should return an object' {
        $Templates = Get-EmailTemplate
        $Templates | Should -BeTrue
    }

}