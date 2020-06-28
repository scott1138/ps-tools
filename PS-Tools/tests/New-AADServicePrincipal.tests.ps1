# Remove module and import the local version we want test
# This assumes the PSD1 file is two folders above this test file
Remove-Module PS-Tools -Force -ErrorAction SilentlyContinue -Verbose:$false
Import-Module "$PSScriptRoot\..\PS-Tools.psd1" -Force -DisableNameChecking 4>$null

Describe 'New-AADServicePrincipal Tests' -Tag 'WindowsOnly' {

    BeforeAll {
        Function New-AzADApplication {}
        Function New-AzADAppCredential {}
        Function New-AzADServicePrincipal {}
        Function New-AzADServicePrincipal {}
    }

    Context 'No Errors' {
        BeforeAll {
            # Prevent Az Module from being installed
            Mock Update-Module { $true } -ModuleName PS-Tools

            Mock Import-Module { $true } -ModuleName PS-Tools

            # Return true when checking for the Az module
            Mock Get-Module { $true } -ModuleName PS-Tools
            
            # Mock Az commands
            Mock  New-AzADApplication {
                @{
                    ObjectID      = New-Guid
                    ApplicationID = New-Guid
                }
            } -ModuleName PS-Tools

            Mock New-AzADAppCredential { $true } -ModuleName PS-Tools

            Mock New-AzADServicePrincipal { $true } -ModuleName PS-Tools

            Mock Login-AzureAD { $true } -ModuleName PS-Tools

            Mock Read-Host { ConvertTo-SecureString -String 'Password' -AsPlainText -Force } -ModuleName PS-Tools

        }

        It 'Generates the desired output when using password auth.' {
            
            $Result = New-AADServicePrincipal -Name 'SP-Mock-AADApp' -AADTenant 'AADTenant' -InformationAction SilentlyContinue

            $Result.ClientID | Should -BeOfType [GUID]
            $Result.Password.Length | Should -be 44
            
        }

        It 'Generates the desired output when using certificate auth.' -Tag 'PS5Only' {

            $Result = New-AADServicePrincipal -Name SP-Mock-AADApp -CertAuth -AADTenant AADTenant -InformationAction SilentlyContinue

            $Result.ClientID | Should -BeOfType [GUID]
            $Result.CertThumbprint.Length | Should -Be 40
            $Result.CertificatePath | Should -Exist
        
        }

    } # End Context 'No Errors'

}