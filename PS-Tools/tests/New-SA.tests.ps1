# Remove module and import the local version we want test
# This assumes the PSD1 file is two folders above this test file
Remove-Module PS-Tools -Force -ErrorAction SilentlyContinue
Import-Module "$PSScriptRoot\..\PS-Tools.psd1" -Force

Describe 'New-SA Tests' {

    InModuleScope PS-Tools {

    }
    
}