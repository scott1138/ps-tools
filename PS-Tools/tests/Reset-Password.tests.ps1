# Remove module and import the local version we want test
# This assumes the PSD1 file is two folders above this test file
Remove-Module PS-Tools -Force -ErrorAction SilentlyContinue -Verbose:$false
Import-Module "$PSScriptRoot\..\PS-Tools.psd1" -Force -DisableNameChecking 4>$null

Describe 'Reset-Password Tests' {

    BeforeAll {
        # Define commands in case the module is not installed.
        Function Get-ADUser {}
        Function Set-ADAccountPassword {[CmdletBinding(SupportsShouldProcess)]param()}

        Mock New-Password {'P@ssw0rd!!'} -ModuleName PS-Tools

        Mock Get-ADUser {$true} -ModuleName PS-Tools

        Mock Set-ADAccountPassword {$true} -ModuleName PS-Tools

        Mock New-OneTimeSecret {
            return 'ASecretKey'
        } -ModuleName PS-Tools

        Mock Send-Email {$true} -ModuleName PS-Tools
    }
    
    Context 'Password is generated' {

        It 'Call New-Password' {
            Reset-Password -Username 'todd' -EmailAddress 'todd@ex.com' -Domain 'ADDomain'

            # Confirm that the New-Password function was called
            Assert-MockCalled -ModuleName PS-Tools New-Password -Scope It 
        }
    }

    Context 'OneTimeSecret key is generated' {

        It 'Call New-OneTimeSecret' {
            Reset-Password -Username 'todd' -EmailAddress 'todd@ex.com' -Domain 'ADDomain'

            # Confirms New-OneTimeSecret was called
            Assert-MockCalled -ModuleName PS-Tools New-OneTimeSecret -Scope It 
        }

        It 'Call New-OneTimeSecret with SecretTTL' {
            Reset-Password -Username 'todd' -EmailAddress 'todd@ex.com' -Domain 'ADDomain' -SecretTTL 4

            # Confirms New-OneTimeSecret was called
            Assert-MockCalled -ModuleName PS-Tools New-OneTimeSecret -Scope It 
        }
    }

    Context 'AD is queried for the user' {

        It 'Call Get-ADUser' {
            Reset-Password -Username 'todd' -EmailAddress 'todd@ex.com' -Domain 'ADDomain'

            # Confirms Get-ADUser was called
            Assert-MockCalled -ModuleName PS-Tools Get-ADUser -Scope It 
        }
    }

    Context 'Password is reset' {

        It 'Call Set-ADAccountPassword' {
            Reset-Password -Username 'todd' -EmailAddress 'todd@ex.com' -Domain 'ADDomain'

            # Confirms Set-ADAccountPassword was called
            Assert-MockCalled -ModuleName PS-Tools Set-ADAccountPassword -Scope It 
        }
    }

    Context 'Validate email address operations' {

        It 'Send email using AD User mail property' {
    
            Mock Get-ADUser {
                @{
                    GivenName = 'Todd'
                    mail      = 'todd@ex.com'
                }
            } -ModuleName PS-Tools

            Reset-Password -Username 'todd' -Domain 'ADDomain'
            
            # Confirms the final step of the process ran
            Assert-MockCalled -ModuleName PS-Tools Send-Email -Scope It
            
        }

        It 'Send email using AD User EmailAddress property' {
    
            Mock Get-ADUser {
                @{
                    GivenName    = 'Todd'
                    EmailAddress = 'todd@ex.com'
                }
            } -ModuleName PS-Tools

            Reset-Password -Username 'todd' -Domain 'ADDomain'
            
            # Confirms the final step of the process ran
            Assert-MockCalled -ModuleName PS-Tools Send-Email -Scope It
            
        }

        It 'Send email using AD User proxyAddresses property' {
    
            Mock Get-ADUser {
                @{
                    GivenName      = 'Todd'
                    proxyAddresses = @('SMTP:todd@ex.com')
                }
            } -ModuleName PS-Tools

            Reset-Password -Username 'todd' -Domain 'ADDomain'
            
            # Confirms the final step of the process ran
            Assert-MockCalled -ModuleName PS-Tools Send-Email -Scope It
            
        }

        It 'Send email using EmailAddress command parameter' {
    
            Mock Get-ADUser {
                @{
                    GivenName      = 'Todd'
                }
            } -ModuleName PS-Tools

            Reset-Password -Username 'todd' -EmailAddress 'todd@ex.com' -Domain 'ADDomain'
            
            # Confirms the final step of the process ran
            Assert-MockCalled -ModuleName PS-Tools Send-Email -Scope It
            
        }

        It 'Fails when the AD object has no email address and the -EmailAddress parameter is not used' {
    
            Mock Get-ADUser {
                @{
                    GivenName      = 'Todd'
                }
            } -ModuleName PS-Tools

            $ErrorCaught = $false

            # -InformationAction Ignore supresses error output for the test
            try {
                Reset-Password -Username 'todd' -Domain 'ADDomain' -InformationAction Ignore
            }
            catch {
                $ErrorCaught = $true
            }
            
            $ErrorCaught | Should -Be $true

        }

    } # End Context 'Validate email address operations'

}