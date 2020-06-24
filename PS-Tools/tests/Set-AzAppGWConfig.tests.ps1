# Remove module and import the local version we want test
# This assumes the PSD1 file is two folders above this test file
Remove-Module PS-Tools -Force -ErrorAction SilentlyContinue
Import-Module "$PSScriptRoot\..\PS-Tools.psd1" -Force

Describe 'Set-AzAppGWConfig Tests' {

    InModuleScope PS-Tools {

        # Mock avoids actual attempts to login
        Function New-AADServicePrincipal {}
        Mock New-AADServicePrincipal {$true}

        Function Select-AzSubscription {}
        Mock Select-AzSubscription {}

        

    }
    
}