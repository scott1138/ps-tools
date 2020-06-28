# Remove module and import the local version we want test
# This assumes the PSD1 file is two folders above this test file
Remove-Module PS-Tools -Force -ErrorAction SilentlyContinue -Verbose:$false
Import-Module "$PSScriptRoot\..\PS-Tools.psd1" -Force -DisableNameChecking 4>$null

Describe 'Set-AzAppGWConfig Tests' {

        
}