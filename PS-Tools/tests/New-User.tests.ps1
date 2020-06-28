# Remove module and import the local version we want test
# This assumes the PSD1 file is two folders above this test file
Remove-Module PS-Tools -Force -ErrorAction SilentlyContinue -Verbose:$false
Import-Module "$PSScriptRoot\..\PS-Tools.psd1" -Force -DisableNameChecking 4>$null

BeforeAll {
    $UserCsvPath = "$env:TEMP\user.csv"

    # Mock avoids actual attempts to login
    Function Connect-AzureADTenant {}
    Mock Connect-AzureADTenant { $true }

    # Mock needs to return $true because the result is used as a condition
    Function New-ADUser {}
    Mock New-ADUser { $true }

    # Mock needs to return $true because the result is used as a condition
    Function Get-ADUser {}
    Mock Get-ADUser { $true }
    
    # Mock defined as needed in tests
    Function Get-ADGroup {}
    
    # Mock does not need to return anything
    Function Add-ADGroupMember {}
    Mock Add-ADGroupMember { $true }

    # Mock avoids attempting to invoke commands on remote systems
    Mock Invoke-Command { $true } 

    # Mock needs to return an object with a RunEndTime propery
    # The time needs to be in the future so it believes the process it complete
    Mock Get-CimInstance { New-Object PSObject -Property @{RunEndTime = (Get-Date).AddHours(1) } }

    # Mock avoids waiting for user input and continues function execution
    Mock Get-Input { $true } -ParameterFilter { $Prompt -eq "Unable to automatically sync with AAD. Please do this manually then type 'yes' to continue." -and $ValidResponses -eq 'yes' }

    # Mock needs to return true because the response is used as a condition
    Function Get-AzADUser {}
    Mock Get-AzADUser { $true }

    # Mock avoids calling the real command
    Function Add-AzADGroupMember {}
    Mock Add-AzADGroupMember { $true }

    # Mock avoids calling the real command
    #Function Send-Email {}
    Mock Send-Email { $true } -ParameterFilter { $TemplateName -eq 'HT_AAD_Account' }
    Mock Send-Email { $true } -ParameterFilter { $TemplateName -eq 'RSA_Request' }

}

Describe 'New-User Tests' -Tag 'WindowsOnly' {

    Context '- CSV Input - All Actions Taken (with AD and AAD Groups)' -Tag 'CSV-Input' {
        BeforeAll {
            $UserProperties = @{
                FirstName    = 'Nancy'
                LastName     = 'Drew'
                Description  = 'Data Test'
                EmailAddress = 'nancy.drew@example.com'
                MobileNumber = '+1 555-111-1234'
                ADGroups     = 'GS-Test1'
                AADGroups    = 'GS-Test2'
                RSA          = 'true'
                PhoneType    = 'iPhone'
            }

            New-Object PSobject -Property $UserProperties | Export-Csv -Path $UserCsvPath -NoTypeInformation
            New-User -Domain 'example.com' -UserFile $UserCsvPath -OutVariable TestOutput -InformationAction Ignore
            Remove-Item -Path $UserCsvPath -Force

            $TestCases = @{
                TestOutput = $TestOutput
            }
        }

        It 'User is created' -TestCases $TestCases {
            $TestOutput.Processed -eq $TestOutput.Created -and $TestOutput.Failed -eq 0 | Should -Be True
            #Should -Invoke Connect-AzureADTenant -Exactly 1 -Scope Context
            #Should -Invoke New-User -Exactly 1 -Scope Context
        }

        It 'AD Groups are added' -TestCases $TestCases {
            # 4 groups are added, 3 base groups and 1 from the CSV
            $TestOutput.Processed -eq $TestOutput.Created -and $TestOutput.Failed -eq 0 | Should -Be True
            Should -Invoke Add-ADGroupMember -Scope Context -Exactly 4
        }

        It 'AAD groups are added' -TestCases $TestCases {
            $TestOutput.Processed -eq $TestOutput.Created -and $TestOutput.Failed -eq 0 | Should -Be True
            Should -Invoke Add-AzADGroupMember -Scope Context -Exactly 1
        }

        It 'User email is sent' -TestCases $TestCases {
            $TestOutput.Processed -eq $TestOutput.Created -and $TestOutput.Failed -eq 0 | Should -Be True
            Should -Invoke -CommandName Send-Email -ParameterFilter { $TemplateName -eq 'HT_AAD_Account' } -Scope Context -Exactly 1
        }

        It 'RSA email is sent' -TestCases $TestCases {
            $TestOutput.Processed -eq $TestOutput.Created -and $TestOutput.Failed -eq 0 | Should -Be True
            Should -Invoke -CommandName Send-Email -ParameterFilter { $TemplateName -eq 'RSA_Request' } -Scope Context -Exactly 1
        }

    } # End Context 'CSV Input - All Actions Taken (with AD and AAD Groups)'

    Context '- Parameter Input - All Actions Taken (with AD and AAD Groups)' -Tag 'Parameter-Input' {
        BeforeAll {
            $UserProperties = @{
                FirstName    = 'Nancy'
                LastName     = 'Drew'
                Description  = 'Data Test'
                EmailAddress = 'nancy.drew@example.com'
                MobileNumber = '+1 555-111-1234'
                ADGroups     = 'GS-Test1'
                AADGroups    = 'GS-Test2'
                RSA          = $true
                PhoneType    = 'iPhone'
            }

            New-User -Domain 'example.com' @UserProperties -OutVariable TestOutput -InformationAction Ignore

            $TestCases = @{
                TestOutput = $TestOutput
            }
        }

        It 'User is created' -TestCases $TestCases {
            $TestOutput.Processed -eq $TestOutput.Created -and $TestOutput.Failed -eq 0 | Should -Be True
            #Should -Invoke New-User -Scope Context
        }

        It 'AD Groups are added' -TestCases $TestCases {
            # 4 groups are added, 3 base groups and 1 from the parameter
            $TestOutput.Processed -eq $TestOutput.Created -and $TestOutput.Failed -eq 0 | Should -Be True
            Should -Invoke Add-ADGroupMember -Scope Context -Exactly 4
        }

        It 'AAD groups are added' -TestCases $TestCases {
            $TestOutput.Processed -eq $TestOutput.Created -and $TestOutput.Failed -eq 0 | Should -Be True
            Should -Invoke Add-AzADGroupMember -Scope Context -Exactly 1
        }

        It 'User email is sent' {
            $TestOutput.Processed -eq $TestOutput.Created -and $TestOutput.Failed -eq 0 | Should -Be True
            Should -Invoke -CommandName Send-Email -ParameterFilter { $TemplateName -eq 'HT_AAD_Account' } -Scope Context -Exactly 1
        }

        It 'RSA email is sent' {
            $TestOutput.Processed -eq $TestOutput.Created -and $TestOutput.Failed -eq 0 | Should -Be True
            Should -Invoke -CommandName Send-Email -ParameterFilter { $TemplateName -eq 'RSA_Request' } -Scope Context -Exactly 1
        }

    } # End Context 'Parameter Input - All Actions Taken (with AD and AAD Groups)'

    Context '- CSV Input - All Actions Taken (with No Groups)' -Tag 'CSV-Input' {
        BeforeAll {
            $UserProperties = @{
                FirstName    = 'Nancy'
                LastName     = 'Drew'
                Description  = 'Data Test'
                EmailAddress = 'nancy.drew@example.com'
                MobileNumber = '+1 555-111-1234'
                ADGroups     = $null
                AADGroups    = $null
                RSA          = 'true'
                PhoneType    = 'iPhone'
            }
            New-Object PSobject -Property $UserProperties | Export-Csv -Path $UserCsvPath -NoTypeInformation
            New-User -Domain 'example.com' -UserFile $UserCsvPath -OutVariable TestOutput -InformationAction Ignore
            Remove-Item -Path $UserCsvPath -Force

            $TestCases = @{
                TestOutput = $TestOutput
            }
        }

        It 'User is created' -TestCases $TestCases {
            $TestOutput.Processed -eq $TestOutput.Created -and $TestOutput.Failed -eq 0 | Should -Be True
            #Should -Invoke New-User -Scope Context
        }

        It 'No additional AD Groups are added' -TestCases $TestCases {
            # There are 3 base groups
            $TestOutput.Processed -eq $TestOutput.Created -and $TestOutput.Failed -eq 0 | Should -Be True
            Should -Invoke Add-ADGroupMember -Scope Context -Exactly 3
        }

        It 'No AAD groups are added' -TestCases $TestCases {
            $TestOutput.Processed -eq $TestOutput.Created -and $TestOutput.Failed -eq 0 | Should -Be True
            Should -Invoke Add-AzADGroupMember -Scope Context -Exactly 0
        }

        It 'User email is sent' -TestCases $TestCases {
            $TestOutput.Processed -eq $TestOutput.Created -and $TestOutput.Failed -eq 0 | Should -Be True
            Should -Invoke -CommandName Send-Email -ParameterFilter { $TemplateName -eq 'HT_AAD_Account' } -Scope Context -Exactly 1
        }

        It 'RSA email is sent' -TestCases $TestCases {
            $TestOutput.Processed -eq $TestOutput.Created -and $TestOutput.Failed -eq 0 | Should -Be True
            Should -Invoke -CommandName Send-Email -ParameterFilter { $TemplateName -eq 'RSA_Request' } -Scope Context -Exactly 1
        }

    } # End Context 'CSV Input - All Actions Taken (with No Groups)'

    Context '- Parameter Input - All Actions Taken (with No Groups)' -Tag 'Parameter-Input' {
        BeforeAll {
            $UserProperties = @{
                Domain       = 'example.com'
                FirstName    = 'Nancy'
                LastName     = 'Drew'
                Description  = 'Data Test'
                EmailAddress = 'nancy.drew@example.com'
                MobileNumber = '+1 555-111-1234'
                RSA          = $true
                PhoneType    = 'iPhone'
            }
            New-User @UserProperties -OutVariable TestOutput -InformationAction Ignore

            $TestCases = @{
                TestOutput = $TestOutput
            }
        }

        It 'User is created' -TestCases $TestCases {
            $TestOutput.Processed -eq $TestOutput.Created -and $TestOutput.Failed -eq 0 | Should -Be True
            #Should -Invoke New-User -Scope Context
        }

        It 'No Additional AD Groups are added' -TestCases $TestCases {
            # There are 3 base groups
            $TestOutput.Processed -eq $TestOutput.Created -and $TestOutput.Failed -eq 0 | Should -Be True
            Should -Invoke Add-ADGroupMember -Scope Context -Exactly 3
        }

        It 'No AAD groups are added' -TestCases $TestCases {
            $TestOutput.Processed -eq $TestOutput.Created -and $TestOutput.Failed -eq 0 | Should -Be True
            Should -Invoke Add-AzADGroupMember -Scope Context -Exactly 0
        }

        It 'User email is sent' -TestCases $TestCases {
            $TestOutput.Processed -eq $TestOutput.Created -and $TestOutput.Failed -eq 0 | Should -Be True
            Should -Invoke -CommandName Send-Email -ParameterFilter { $TemplateName -eq 'HT_AAD_Account' } -Scope Context -Exactly 1
        }

        It 'RSA email is sent' -TestCases $TestCases {
            $TestOutput.Processed -eq $TestOutput.Created -and $TestOutput.Failed -eq 0 | Should -Be True
            Should -Invoke -CommandName Send-Email -ParameterFilter { $TemplateName -eq 'RSA_Request' } -Scope Context -Exactly 1
        }

    } # End Context 'Parameter Input - All Actions Taken (with No Groups)'

    Context '- CSV Input - All Actions Taken (No RSA)' -Tag 'CSV-Input' {
        BeforeAll {
            $UserProperties = @{
                FirstName    = 'Nancy'
                LastName     = 'Drew'
                Description  = 'Data Test'
                EmailAddress = 'nancy.drew@example.com'
                MobileNumber = '+1 555-111-1234'
                ADGroups     = $null
                AADGroups    = $null
                RSA          = $null
                PhoneType    = $null
            }
            New-Object PSobject -Property $UserProperties | Export-Csv -Path $UserCsvPath -NoTypeInformation
            New-User -Domain 'example.com' -UserFile $UserCsvPath -OutVariable TestOutput -InformationAction Ignore
            Remove-Item -Path $UserCsvPath -Force

            $TestCases = @{
                TestOutput = $TestOutput
            }
        }

        It 'User is created' -TestCases $TestCases {
            $TestOutput.Processed -eq $TestOutput.Created -and $TestOutput.Failed -eq 0 | Should -Be True
            #Should -Invoke New-User -Scope Context
        }

        It 'No additional AD Groups are added' -TestCases $TestCases {
            # There are 3 base groups
            $TestOutput.Processed -eq $TestOutput.Created -and $TestOutput.Failed -eq 0 | Should -Be True
            Should -Invoke Add-ADGroupMember -Scope Context -Exactly 3
        }

        It 'No AAD groups are added' -TestCases $TestCases {
            $TestOutput.Processed -eq $TestOutput.Created -and $TestOutput.Failed -eq 0 | Should -Be True
            Should -Invoke Add-AzADGroupMember -Scope Context -Exactly 0
        }

        It 'User email is sent' -TestCases $TestCases {
            $TestOutput.Processed -eq $TestOutput.Created -and $TestOutput.Failed -eq 0 | Should -Be True
            Should -Invoke -CommandName Send-Email -ParameterFilter { $TemplateName -eq 'HT_AAD_Account' } -Scope Context -Exactly 1
        }

        It 'RSA email is not sent' -TestCases $TestCases {
            $TestOutput.Processed -eq $TestOutput.Created -and $TestOutput.Failed -eq 0 | Should -Be True
            Should -Invoke -CommandName Send-Email -ParameterFilter { $TemplateName -eq 'RSA_Request' } -Scope Context -Exactly 0
        }

    } # End Context 'CSV Input - All Actions Taken (No RSA)'

    Context '- Parameter Input - All Actions Taken (No RSA)' -Tag 'Parameter-Input' {
        BeforeAll {
            $UserProperties = @{
                Domain       = 'example.com'
                FirstName    = 'Nancy'
                LastName     = 'Drew'
                Description  = 'Data Test'
                EmailAddress = 'nancy.drew@example.com'
                MobileNumber = '+1 555-111-1234'
            }
            New-User @UserProperties -OutVariable TestOutput -InformationAction Ignore
            
            $TestCases = @{
                TestOutput = $TestOutput
            }
        }

        It 'User is created' -TestCases $TestCases {
            $TestOutput.Processed -eq $TestOutput.Created -and $TestOutput.Failed -eq 0 | Should -Be True
            #Should -Invoke New-User -Scope Context
        }

        It 'No Additional AD Groups are added' -TestCases $TestCases {
            # There are 3 base groups
            $TestOutput.Processed -eq $TestOutput.Created -and $TestOutput.Failed -eq 0 | Should -Be True
            Should -Invoke Add-ADGroupMember -Scope Context -Exactly 3
        }

        It 'No AAD groups are added' -TestCases $TestCases {
            $TestOutput.Processed -eq $TestOutput.Created -and $TestOutput.Failed -eq 0 | Should -Be True
            Should -Invoke Add-AzADGroupMember -Scope Context -Exactly 0
        }

        It 'User email is sent' -TestCases $TestCases {
            $TestOutput.Processed -eq $TestOutput.Created -and $TestOutput.Failed -eq 0 | Should -Be True
            Should -Invoke -CommandName Send-Email -ParameterFilter { $TemplateName -eq 'HT_AAD_Account' } -Scope Context -Exactly 1
        }

        It 'RSA email is not sent' -TestCases $TestCases {
            $TestOutput.Processed -eq $TestOutput.Created -and $TestOutput.Failed -eq 0 | Should -Be True
            Should -Invoke -CommandName Send-Email -ParameterFilter { $TemplateName -eq 'RSA_Request' } -Scope Context -Exactly 0
        }

    } # End Context 'Parameter Input - All Actions Taken (No RSA)'

    Context '- Parameter Input - All Actions Taken (with Source User - Multiple Groups)' -Tag 'Parameter-Input' {
        BeforeAll {
            $UserProperties = @{
                Domain       = 'example.com'
                FirstName    = 'Nancy'
                LastName     = 'Drew'
                Description  = 'Data Test'
                EmailAddress = 'nancy.drew@example.com'
                MobileNumber = '+1 555-111-1234'
                SourceUser   = 'SomeUser'
                RSA          = $true
                PhoneType    = 'iPhone'
            }

            Mock Get-ADGroup {
                New-Object PSObject -Property @{Name = @('Group1', 'Group2') }
            }

            New-User @UserProperties -OutVariable TestOutput -InformationAction Ignore

            $TestCases = @{
                TestOutput = $TestOutput
            }
        }

        It 'Retrives source user groups' -TestCases $TestCases {
            $TestOutput.Processed -eq $TestOutput.Created -and $TestOutput.Failed -eq 0 | Should -Be True
            Should -Invoke Get-ADGroup -Exactly 1 -Scope Context
        }

        It 'User is created' -TestCases $TestCases {
            $TestOutput.Processed -eq $TestOutput.Created -and $TestOutput.Failed -eq 0 | Should -Be True
            #Should -Invoke New-User -Scope Context
        }

        It 'AD Groups are added' -TestCases $TestCases {
            # 5 groups are added, 3 base groups and 2 source user groups
            $TestOutput.Processed -eq $TestOutput.Created -and $TestOutput.Failed -eq 0 | Should -Be True
            Should -Invoke Add-ADGroupMember -Scope Context -Exactly 5
        }

        It 'No AAD groups are added' -TestCases $TestCases {
            $TestOutput.Processed -eq $TestOutput.Created -and $TestOutput.Failed -eq 0 | Should -Be True
            Should -Invoke Add-AzADGroupMember -Scope Context -Exactly 0
        }

        It 'Emails are sent' -TestCases $TestCases {
            $TestOutput.Processed -eq $TestOutput.Created -and $TestOutput.Failed -eq 0 | Should -Be True
            Should -Invoke Send-Email -Scope Context -Exactly 2
        }

    } # End Context 'Parameter Input - All Actions Taken (with Source User - Multiple Groups)'

    Context '- Parameter Input - All Actions Taken (with Source User - Single Group)' -Tag 'Parameter-Input' {
        BeforeAll {
            $UserProperties = @{
                Domain       = 'example.com'
                FirstName    = 'Nancy'
                LastName     = 'Drew'
                Description  = 'Data Test'
                EmailAddress = 'nancy.drew@example.com'
                MobileNumber = '+1 555-111-1234'
                SourceUser   = 'SomeUser'
                RSA          = $true
                PhoneType    = 'iPhone'
            }

            Mock Get-ADGroup {
                New-Object PSObject -Property @{Name = @('Group1') }
            }

            New-User @UserProperties -OutVariable TestOutput -InformationAction Ignore

            $TestCases = @{
                TestOutput = $TestOutput
            }
        }

        It 'Retrives source user groups' -TestCases $TestCases {
            $TestOutput.Processed -eq $TestOutput.Created -and $TestOutput.Failed -eq 0 | Should -Be True
            Should -Invoke Get-ADGroup -Scope Context
        }

        It 'User is created' -TestCases $TestCases {
            $TestOutput.Processed -eq $TestOutput.Created -and $TestOutput.Failed -eq 0 | Should -Be True
            #Should -Invoke New-User -Scope Context
        }

        It 'AD Groups are added' -TestCases $TestCases {
            # 4 groups are added, 3 base groups and 1 source user group
            $TestOutput.Processed -eq $TestOutput.Created -and $TestOutput.Failed -eq 0 | Should -Be True
            Should -Invoke Add-ADGroupMember -Scope Context -Exactly 4
        }

        It 'No AAD groups are added' -TestCases $TestCases {
            $TestOutput.Processed -eq $TestOutput.Created -and $TestOutput.Failed -eq 0 | Should -Be True
            Should -Invoke Add-AzADGroupMember -Scope Context -Exactly 0
        }

        It 'Emails are sent' -TestCases $TestCases {
            $TestOutput.Processed -eq $TestOutput.Created -and $TestOutput.Failed -eq 0 | Should -Be True
            Should -Invoke Send-Email -Scope Context -Exactly 2
        }

    } # End Context 'Parameter Input - All Actions Taken (with Source User - Single Group)'

    Context '- Failed Actions - Validate Output' -Tag 'Failed-Actions' {
        BeforeAll {
            $UserProperties = @{
                Domain       = 'example.com'
                FirstName    = 'Nancy'
                LastName     = 'Drew'
                Description  = 'Data Test'
                EmailAddress = 'nancy.drew@example.com'
                MobileNumber = '+1 555-111-1234'
                ADGroups     = 'GS-Test1'
                AADGroups    = 'GS-Test2'
                RSA          = $true
                PhoneType    = 'iPhone'
            }

            $TestCases = @{
                UserProperties = $UserProperties
            }

        }

        It 'User creation fails' -TestCases $TestCases {
            Mock New-ADUser { throw 'Could not create user' }
            New-User @UserProperties -OutVariable TestOutput -InformationAction Ignore
            $TestOutput.Processed -eq $TestOutput.Failed -and $TestOutput.Created -eq 0 | Should -Be True
            $TestOutput.FailedUsers.Issue | Should -Be 'Could not create user'
            #Should -Invoke New-User -Scope It
        }

        It 'AD Group membership fails' -TestCases $TestCases {
            Mock Add-ADGroupMember { throw 'Could not add user to group' }
            New-User @UserProperties -OutVariable TestOutput -InformationAction Ignore
            $TestOutput.Processed -eq $TestOutput.Failed -and $TestOutput.Created -eq 0 | Should -Be True
            $TestOutput.FailedUsers.Issue | Should -Be 'Could not add user to group'
            Should -Invoke Add-ADGroupMember -Scope It
        }

    } # End Context 'Failed Actions - Validate Output'

    Context '- CSV Data Validation - Error Checking' -Tag 'CSV-Validation' {

        It 'CSV - Missing field' {
            $UserProperties = @{
                FirstName    = 'Nancy'
                LastName     = 'Drew'
                Description  = 'Data Test'
                EmailAddress = 'nancy.drew@example.com'
                MobileNumber = '+1 555-111-1234'
                ADGroups     = ''
                AADGroups    = ''
                RSA          = ''
            }
            New-Object PSobject -Property $UserProperties | Export-Csv -Path $UserCsvPath -NoTypeInformation

            try {
                New-User -Domain 'example.com' -UserFile $UserCsvPath -OutVariable TestOutput -InformationAction Ignore
            } 
            catch {
                $ErrorOccurred = $true
            }

            $ErrorOccurred | Should -Be True
            $TestOutput | Should -Be 'PhoneType'

            Remove-Item -Path $UserCsvPath -Force

        }

        It 'FirstName - Blank or Empty' {
            $UserProperties = @{
                FirstName    = ''
                LastName     = 'Drew'
                Description  = 'Data Test'
                EmailAddress = 'nancy.drew@example.com'
                MobileNumber = '+1 555-111-1234'
                ADGroups     = ''
                AADGroups    = ''
                RSA          = ''
                PhoneType    = ''
            }
            New-Object PSobject -Property $UserProperties | Export-Csv -Path $UserCsvPath -NoTypeInformation

            try {
                New-User -Domain 'example.com' -UserFile $UserCsvPath -OutVariable TestOutput -InformationAction Ignore
            } 
            catch {
                $ErrorOccurred = $true
            }

            $ErrorOccurred | Should -Be True
            $TestOutput.Issue | Should -Be 'FirstName'

            Remove-Item -Path $UserCsvPath -Force

        }

        It 'LastName - Blank or Empty' {
            $UserProperties = @{
                FirstName    = 'Nancy'
                LastName     = ''
                Description  = 'Data Test'
                EmailAddress = 'nancy.drew@example.com'
                MobileNumber = '+1 555-111-1234'
                ADGroups     = ''
                AADGroups    = ''
                RSA          = ''
                PhoneType    = ''
            }
            New-Object PSobject -Property $UserProperties | Export-Csv -Path $UserCsvPath -NoTypeInformation

            try {
                New-User -Domain 'example.com' -UserFile $UserCsvPath -OutVariable TestOutput -InformationAction Ignore
            } 
            catch {
                $ErrorOccurred = $true
            }

            $ErrorOccurred | Should -Be True
            $TestOutput.Issue | Should -Be 'LastName'

            Remove-Item -Path $UserCsvPath -Force

        }

        It 'Description - Blank or Empty' {
            $UserProperties = @{
                FirstName    = 'Nancy'
                LastName     = 'Drew'
                Description  = ''
                EmailAddress = 'nancy.drew@example.com'
                MobileNumber = '+1 555-111-1234'
                ADGroups     = ''
                AADGroups    = ''
                RSA          = ''
                PhoneType    = ''
            }
            New-Object PSobject -Property $UserProperties | Export-Csv -Path $UserCsvPath -NoTypeInformation

            try {
                New-User -Domain 'example.com' -UserFile $UserCsvPath -OutVariable TestOutput -InformationAction Ignore
            } 
            catch {
                $ErrorOccurred = $true
            }

            $ErrorOccurred | Should -Be True
            $TestOutput.Issue | Should -Be 'Description'

            Remove-Item -Path $UserCsvPath -Force

        }

        It 'Description - WhiteSpace' {
            $UserProperties = @{
                FirstName    = 'Nancy'
                LastName     = 'Drew'
                Description  = ' '
                EmailAddress = 'nancy.drew@example.com'
                MobileNumber = '+1 555-111-1234'
                ADGroups     = ''
                AADGroups    = ''
                RSA          = ''
                PhoneType    = ''
            }
            New-Object PSobject -Property $UserProperties | Export-Csv -Path $UserCsvPath -NoTypeInformation

            try {
                New-User -Domain 'example.com' -UserFile $UserCsvPath -OutVariable TestOutput -InformationAction Ignore
            } 
            catch {
                $ErrorOccurred = $true
            }

            $ErrorOccurred | Should -Be True
            $TestOutput.Issue | Should -Be 'Description'

            Remove-Item -Path $UserCsvPath -Force

        }

        It 'EmailAddress - Blank or Empty' {
            $UserProperties = @{
                FirstName    = 'Nancy'
                LastName     = 'Drew'
                Description  = 'Data Test'
                EmailAddress = ''
                MobileNumber = '+1 555-111-1234'
                ADGroups     = ''
                AADGroups    = ''
                RSA          = ''
                PhoneType    = ''
            }
            New-Object PSobject -Property $UserProperties | Export-Csv -Path $UserCsvPath -NoTypeInformation

            try {
                New-User -Domain 'example.com' -UserFile $UserCsvPath -OutVariable TestOutput -InformationAction Ignore
            } 
            catch {
                $ErrorOccurred = $true
            }

            $ErrorOccurred | Should -Be True
            $TestOutput.Issue | Should -Be 'EmailAddress'

            Remove-Item -Path $UserCsvPath -Force

        }

        It 'EmailAddress - Invalid Address' {
            $UserProperties = @{
                FirstName    = 'Nancy'
                LastName     = 'Drew'
                Description  = 'Data Test'
                EmailAddress = 'nancy.drew.example.com'
                MobileNumber = '+1 555-111-1234'
                ADGroups     = ''
                AADGroups    = ''
                RSA          = ''
                PhoneType    = ''
            }
            New-Object PSobject -Property $UserProperties | Export-Csv -Path $UserCsvPath -NoTypeInformation

            try {
                New-User -Domain 'example.com' -UserFile $UserCsvPath -OutVariable TestOutput -InformationAction Ignore
            } 
            catch {
                $ErrorOccurred = $true
            }

            $ErrorOccurred | Should -Be True
            $TestOutput.Issue | Should -Be 'EmailAddress'

            Remove-Item -Path $UserCsvPath -Force

        }

        It 'MobileNumber - Blank or Empty' {
            $UserProperties = @{
                FirstName    = 'Nancy'
                LastName     = 'Drew'
                Description  = 'Data Test'
                EmailAddress = 'nancy.drew@example.com'
                MobileNumber = ''
                ADGroups     = ''
                AADGroups    = ''
                RSA          = ''
                PhoneType    = ''
            }
            New-Object PSobject -Property $UserProperties | Export-Csv -Path $UserCsvPath -NoTypeInformation

            try {
                New-User -Domain 'example.com' -UserFile $UserCsvPath -OutVariable TestOutput -InformationAction Ignore
            } 
            catch {
                $ErrorOccurred = $true
            }

            $ErrorOccurred | Should -Be True
            $TestOutput.Issue | Should -Be 'MobileNumber'

            Remove-Item -Path $UserCsvPath -Force

        }

        It 'MobileNumber - Invalid Number (US)' {
            $UserProperties = @{
                FirstName    = 'Nancy'
                LastName     = 'Drew'
                Description  = 'Data Test'
                EmailAddress = 'nancy.drew@example.com'
                MobileNumber = '+1 555-111-123'
                ADGroups     = ''
                AADGroups    = ''
                RSA          = ''
                PhoneType    = ''
            }
            New-Object PSobject -Property $UserProperties | Export-Csv -Path $UserCsvPath -NoTypeInformation

            try {
                New-User -Domain 'example.com' -UserFile $UserCsvPath -OutVariable TestOutput -InformationAction Ignore
            } 
            catch {
                $ErrorOccurred = $true
            }

            $ErrorOccurred | Should -Be True
            $TestOutput.Issue | Should -Be 'MobileNumber'

            Remove-Item -Path $UserCsvPath -Force

        }

        It 'RSA - Invalid Value' {
            $UserProperties = @{
                FirstName    = 'Nancy'
                LastName     = 'Drew'
                Description  = 'Data Test'
                EmailAddress = 'nancy.drew@example.com'
                MobileNumber = '+1 555-111-1234'
                ADGroups     = ''
                AADGroups    = ''
                RSA          = 't'
                PhoneType    = ''
            }
            New-Object PSobject -Property $UserProperties | Export-Csv -Path $UserCsvPath -NoTypeInformation

            try {
                New-User -Domain 'example.com' -UserFile $UserCsvPath -OutVariable TestOutput -InformationAction Ignore
            } 
            catch {
                $ErrorOccurred = $true
            }

            $ErrorOccurred | Should -Be True
            $TestOutput.Issue | Should -Be 'RSA'

            Remove-Item -Path $UserCsvPath -Force

        }

        It 'RSA - Missing PhoneType' {
            $UserProperties = @{
                FirstName    = 'Nancy'
                LastName     = 'Drew'
                Description  = 'Data Test'
                EmailAddress = 'nancy.drew@example.com'
                MobileNumber = '+1 555-111-1234'
                ADGroups     = ''
                AADGroups    = ''
                RSA          = 'true'
                PhoneType    = ''
            }
            New-Object PSobject -Property $UserProperties | Export-Csv -Path $UserCsvPath -NoTypeInformation

            try {
                New-User -Domain 'example.com' -UserFile $UserCsvPath -OutVariable TestOutput -InformationAction Ignore
            } 
            catch {
                $ErrorOccurred = $true
            }

            $ErrorOccurred | Should -Be True
            $TestOutput.Issue | Should -Be 'PhoneType'

            Remove-Item -Path $UserCsvPath -Force

        }

        It 'RSA - Invalid PhoneType' {
            $UserProperties = @{
                FirstName    = 'Nancy'
                LastName     = 'Drew'
                Description  = 'Data Test'
                EmailAddress = 'nancy.drew@example.com'
                MobileNumber = '+1 555-111-1234'
                ADGroups     = ''
                AADGroups    = ''
                RSA          = 'true'
                PhoneType    = 'Pixel'
            }
            New-Object PSobject -Property $UserProperties | Export-Csv -Path $UserCsvPath -NoTypeInformation

            try {
                New-User -Domain 'example.com' -UserFile $UserCsvPath -OutVariable TestOutput -InformationAction Ignore
            } 
            catch {
                $ErrorOccurred = $true
            }

            $ErrorOccurred | Should -Be True
            $TestOutput.Issue | Should -Be 'PhoneType'

            Remove-Item -Path $UserCsvPath -Force

        }

    } # End Context 'CSV Data Validation - Error Checking'

    Context '- Parameter Validation Error Checking' -Tag 'Parameter-Validation' {

        It 'FirstName - Blank or Empty' {
            
            $UserProperties = @{
                Domain       = 'example.com'
                FirstName    = ''
                LastName     = 'Drew'
                Description  = 'Data Test'
                EmailAddress = 'nancy.drew@example.com'
                MobileNumber = '+1 555-111-1234'
            }

            { New-User @UserProperties -InformationAction Ignore } | Should -Throw 'Cannot bind argument to parameter ''FirstName'' because it is an empty string.'

        }

        It 'LastName - Blank or Empty' {

            $UserProperties = @{
                Domain       = 'example.com'
                FirstName    = 'Nancy'
                LastName     = ''
                Description  = 'Data Test'
                EmailAddress = 'nancy.drew@example.com'
                MobileNumber = '+1 555-111-1234'
            }

            { New-User @UserProperties -InformationAction Ignore } | Should -Throw 'Cannot bind argument to parameter ''LastName'' because it is an empty string.'


        }

        It 'Description - Blank or Empty' {
            
            $UserProperties = @{
                Domain       = 'example.com'
                FirstName    = 'Nancy'
                LastName     = 'Drew'
                Description  = ''
                EmailAddress = 'nancy.drew@example.com'
                MobileNumber = '+1 555-111-1234'
            }

            { New-User @UserProperties -InformationAction Ignore } | Should -Throw 'Cannot bind argument to parameter ''Description'' because it is an empty string.'

        }

        It 'Description - WhiteSpace' {
            $UserProperties = @{
                Domain       = 'example.com'
                FirstName    = 'Nancy'
                LastName     = 'Drew'
                Description  = ' '
                EmailAddress = 'nancy.drew@example.com'
                MobileNumber = '+1 555-111-1234'
            }

            try {
                New-User @UserProperties -OutVariable TestOutput -InformationAction Ignore
            } 
            catch {
                $ErrorOccurred = $true
            }

            $ErrorOccurred | Should -Be True
            $TestOutput.Issue | Should -Be 'Description'
        }

        It 'EmailAddress - Blank or Empty' {
            $UserProperties = @{
                Domain       = 'example.com'
                FirstName    = 'Nancy'
                LastName     = 'Drew'
                Description  = 'Data Test'
                EmailAddress = ''
            }

            { New-User @UserProperties -InformationAction Ignore } | Should -Throw 'Cannot bind argument to parameter ''EmailAddress'' because it is an empty string.'

        }

        It 'EmailAddress - Invalid Address' {
            $UserProperties = @{
                Domain       = 'example.com'
                FirstName    = 'Nancy'
                LastName     = 'Drew'
                Description  = 'Data Test'
                EmailAddress = 'nancy.drew.example.com'
                MobileNumber = '+1 555-111-1234'
            }

            try {
                New-User @UserProperties -OutVariable TestOutput -InformationAction Ignore
            }
            catch {
                $ErrorOccurred = $true
            }

            $ErrorOccurred | Should -Be True
            $TestOutput.Issue | Should -Be 'EmailAddress'
        }

        It 'MobileNumber - Blank or Empty' {
            $UserProperties = @{
                Domain       = 'example.com'
                FirstName    = 'Nancy'
                LastName     = 'Drew'
                Description  = 'Data Test'
                EmailAddress = 'nancy.drew@example.com'
                MobileNumber = ''
            }

            { New-User @UserProperties -InformationAction Ignore } | Should -Throw 'Cannot bind argument to parameter ''MobileNumber'' because it is an empty string.'
        }

        It 'MobileNumber - Invalid Number (US)' {
            $UserProperties = @{
                Domain       = 'example.com'
                FirstName    = 'Nancy'
                LastName     = 'Drew'
                Description  = 'Data Test'
                EmailAddress = 'nancy.drew@example.com'
                MobileNumber = '+1 555-111-123'
            }

            try {
                New-User @UserProperties -OutVariable TestOutput -InformationAction Ignore
            }
            catch {
                $ErrorOccurred = $true
            }

            $ErrorOccurred | Should -Be True
            $TestOutput.Issue | Should -Be 'MobileNumber'
        }

        It 'RSA - Missing PhoneType' {
            $UserProperties = @{
                Domain       = 'example.com'
                FirstName    = 'Nancy'
                LastName     = 'Drew'
                Description  = 'Data Test'
                EmailAddress = 'nancy.drew@example.com'
                MobileNumber = '+1 555-111-1234'
                RSA          = $true
                PhoneType    = ''
            }
            { New-User @UserProperties -InformationAction Ignore } | Should -Throw 'Cannot validate argument on parameter ''PhoneType''*'
        }

        It 'RSA - Invalid PhoneType' {
            $UserProperties = @{
                Domain       = 'example.com'
                FirstName    = 'Nancy'
                LastName     = 'Drew'
                Description  = 'Data Test'
                EmailAddress = 'nancy.drew@example.com'
                MobileNumber = '+1 555-111-1234'
                RSA          = $true
                PhoneType    = 'Pixel'
            }
            { New-User @UserProperties -InformationAction Ignore } | Should -Throw 'Cannot validate argument on parameter ''PhoneType''*'
        }

    } # End Context 'Parameter Validation Error Checking'
    
}
