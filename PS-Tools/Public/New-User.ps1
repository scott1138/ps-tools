function New-User {

    [CmdletBinding(
        DefaultParameterSetName = 'NoRSA',
        SupportsShouldProcess = $True
    )]

    param (
        [string] $Domain,

        [Parameter(
            ParameterSetName = 'NoRSA',
            Mandatory = $True
        )]
        [Parameter(
            ParameterSetName = 'RSA',
            Mandatory = $True
        )]
        [string] $FirstName,

        [Parameter(
            ParameterSetName = 'NoRSA',
            Mandatory = $True
        )]
        [Parameter(
            ParameterSetName = 'RSA',
            Mandatory = $True
        )]
        [string] $LastName,

        [Parameter(
            ParameterSetName = 'NoRSA',
            Mandatory = $True
        )]
        [Parameter(
            ParameterSetName = 'RSA',
            Mandatory = $True
        )]
        [string] $EmailAddress,

        [Parameter(
            ParameterSetName = 'NoRSA',
            Mandatory = $True
        )]
        [Parameter(
            ParameterSetName = 'RSA',
            Mandatory = $True
        )]
        [string] $Description,

        [Parameter(
            ParameterSetName = 'NoRSA'
        )]
        [Parameter(
            ParameterSetName = 'RSA'
        )]
        [string[]] $ADGroups,

        [Parameter(
            ParameterSetName = 'NoRSA'
        )]
        [Parameter(
            ParameterSetName = 'RSA'
        )]
        [string[]] $AADGroups,
        
        [Parameter(
            ParameterSetName = 'NoRSA',
            Mandatory = $True
        )]
        [Parameter(
            ParameterSetName = 'RSA',
            Mandatory = $True
        )]
        [string] $MobileNumber,

        [Parameter(
            ParameterSetName = 'NoRSA'
        )]
        [Parameter(
            ParameterSetName = 'RSA'
        )]
        [string] $SourceUser,

        [Parameter(
            ParameterSetName = 'RSA',
            Mandatory = $True
        )]
        [switch] $RSA,

        [Parameter(
            ParameterSetName = 'RSA',
            Mandatory = $True
        )]
        [ValidateSet("Android", "iPhone")]
        [string] $PhoneType,

        [Parameter(
            ParameterSetName = 'FromFile',
            Mandatory = $True
        )]
        [string] $UserFile
    )

    begin {

        $ErrorActionPreference = 'Stop'

        if ($PSBoundParameters['Debug']) {
            $DebugPreference = 'Continue'
        }

        # Added for Pester testing when we don't want to show output during the test.
        # Result of a PowerShell bug that doesn't allow the Ignore preference in Adv Functions.
        # https://github.com/PowerShell/PowerShell/issues/1759
        if ($InformationPreference -eq 'Ignore') { 
            $InformationPreference = 'Ignore'
        }

        Write-Debug $PSCmdlet.ParameterSetName
    }

    process {

        function Exit-Function {
            param (
                [hashtable] $Parameters
            )
            Write-Verbose "Users processed: $($Users.Count)"
            Write-Verbose "Users created  : $($CreatedUsers.Count)"
            Write-Verbose "Users failed   : $($FailedUsers.Count)"

            # Output user counts for testing
            if ($Parameters.Keys -contains 'OutVariable') {
                $Properties = @{
                    Processed    = $Users.Count
                    Created      = $CreatedUsers.Count
                    Failed       = $FailedUsers.Count
                    CreatedUsers = $CreatedUsers
                    FailedUsers  = $FailedUsers
                }
                New-Object PSObject -Property $Properties
            }
            else {
                # Output failed users to CSV for analysis
                if ($FailedUsers.Count -gt 0) {
                    $FailedUsersCsv = "$env:TEMP\failedusers_$(Get-Date -Format FileDateTime).csv"
                    $FailedUsers | Select-Object Issue, FirstName, LastName, Description, EmailAddress, MobileNumber, ADGroups, AADGroups, RSA, PhoneType | Export-Csv -NoTypeInformation -Path $FailedUsersCsv
                    Write-InformationPlus "Failed users written to file: $FailedUsersCsv" -ForegroundColor Yellow
                }
            }
        } # End Exit-Function

        # Check for Az Module
        if (-not (Get-Module -Name Az -ListAvailable)) {
            #Format-Error -e [System.Exception]::new('Required module Az not installed.')
            Write-InformationPlus 'Required module Az not installed.' -ForegroundColor Yellow
            break
        }

        # Check for ActiveDirectory module
        if (-not (Get-Module -Name ActiveDirectory -ListAvailable)) {
            #Format-Error -e [System.Exception]::new('Required module Az not installed.')
            Write-InformationPlus 'Required module ActiveDirectory not installed.' -ForegroundColor Yellow
            break
        }

        # Check Module Version, skip when testing
        if ($PSBoundParameters.Keys -notcontains 'OutVariable') {
            Test-ModuleVersion
        }

        # Set up arrays to store user states
        # Created Users to be notified
        $CreatedUsers = @()
        # Failed Users to be output to a file
        $Failedusers = @()

        # if a file has been provided for users, import it.
        # if not, create the $Users object to be handled by the loop
        if (-not [string]::IsNullOrWhiteSpace($UserFile)) {
            try {
                #  Convert CSV data to an explicit array to fix indexof issue in Pester tests.
                $Users = @(Import-Csv $UserFile)
            }
            catch {
                Format-Error -e $_ -Message 'Unable to import the user file.'
            }

            # Validate the user file contains the required properties 
            $ValidProperties = @('FirstName', 'LastName', 'Description', 'EmailAddress', 'ADGroups', 'AADGroups', 'RSA', 'PhoneType', 'MobileNumber')
            
            try {
                # Validate the user file contains at least one user
                if ($null -eq $Users) {
                    Throw "There are no users in the provided file"
                }
                # If a difference is found, compare-object will return true and the script will fail
                elseif ([boolean](Compare-Object -ReferenceObject $ValidProperties -DifferenceObject ($Users[0].psobject.Properties.Name))) {
                    $MissingProperties = (Compare-Object -ReferenceObject $ValidProperties -DifferenceObject ($Users[0].psobject.Properties.Name) -Passthru) -join ','
                    # if output is requested as a variable, output $MissingProperties
                    if ($PSBoundParameters.Keys -contains 'OutVariable') {
                        $MissingProperties
                    }
                    Throw "The user file is missing properties: $MissingProperties"
                }
            }
            catch {
                Format-Error -e $_
            }
        }
        else {
            $Properties = @{
                'FirstName'    = $FirstName
                'LastName'     = $LastName
                'Description'  = $Description
                'EmailAddress' = $EmailAddress
                'RSA'          = if ($PSBoundParameters.Keys -contains 'RSA') { $true } else { $false }
                'PhoneType'    = $PhoneType
                'MobileNumber' = $MobileNumber
                # Making command line parameters match csv fields for processing
                'ADGroups'     = if (-not [string]::IsNullOrWhiteSpace($ADGroups)) { $ADGroups -join ';' } else { $null }
                'AADGroups'    = if (-not [string]::IsNullOrWhiteSpace($AADGroups)) { $AADGroups -join ';' } else { $null }
            }
            $Users = @(New-Object psobject -Property $Properties)
            # if a source user was provided, add any ADGroups that user is in to the user object.
            if ($PSBoundParameters.Keys -contains 'SourceUser') {
                $SourceUserGroups = (Get-ADUser -filter { SamAccountName -eq $SourceUser -or UserPrincipalName -eq $SourceUser } -Properties MemberOf).MemberOf
                $GroupNames = ($SourceUserGroups | Get-ADGroup -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name)
                [array]$Users[0].ADGroups = $GroupNames
            }
        }

        # Validate that each user has the required properties.
        # FirstName, LastName, Description, and MobileNumber CANNOT be empty for any user.
        # Any user with RSA set to true MUST provide a phone type.
        # When we add the LineNumber property we add 2 to the index to account for ordinal numbering and the csv header
        $Script:DataValidated = $true
        $InvalidUsers = @()
        foreach ($User in $Users) {
            if ([string]::IsNullOrWhiteSpace($User.FirstName)) {
                $Script:DataValidated = $false
                $User | Add-Member -MemberType NoteProperty -Name 'LineNumber' -Value ($Users.IndexOf($User) + 2)
                $User | Add-Member -MemberType NoteProperty -Name 'Issue' -Value 'FirstName'
                $InvalidUsers += $User
                continue
            }
            elseif ([string]::IsNullOrWhiteSpace($User.LastName)) {
                $Script:DataValidated = $false
                $User | Add-Member -MemberType NoteProperty -Name 'LineNumber' -Value ($Users.IndexOf($User) + 2)
                $User | Add-Member -MemberType NoteProperty -Name 'Issue' -Value 'LastName'
                $InvalidUsers += $User
                continue
            }
            elseif ($User.FirstName.Length + $User.LastName.Length -gt 20) {
                $Script:DataValidated = $false
                $User | Add-Member -MemberType NoteProperty -Name 'LineNumber' -Value ($Users.IndexOf($User) + 2)
                $User | Add-Member -MemberType NoteProperty -Name 'Issue' -Value 'UserName over 20 characters'
                $InvalidUsers += $User
                continue
            }
            elseif ([string]::IsNullOrWhiteSpace($User.Description)) {
                $Script:DataValidated = $false
                $User | Add-Member -MemberType NoteProperty -Name 'LineNumber' -Value ($Users.IndexOf($User) + 2)
                $User | Add-Member -MemberType NoteProperty -Name 'Issue' -Value 'Description'
                $InvalidUsers += $User
                continue
            }
            elseif (-not (Test-EmailAddress -EmailAddress $User.EmailAddress)) {
                $Script:DataValidated = $false
                $User | Add-Member -MemberType NoteProperty -Name 'LineNumber' -Value ($Users.IndexOf($User) + 2)
                $User | Add-Member -MemberType NoteProperty -Name 'Issue' -Value 'EmailAddress'
                $InvalidUsers += $User
                continue
            }
            # Phone number RegEx ensures we get the +<country code> <number>.  The + and the space are mandatory!
            # The remainder matches a US number with dashes for or a number with no dashes
            elseif ([string]::IsNullOrWhiteSpace($User.MobileNumber) -or $User.MobileNumber -notmatch '^\+\d{1,2} \d{1,3}-?\d{1,3}-?\d{4,}$') {
                $Script:DataValidated = $false
                $User | Add-Member -MemberType NoteProperty -Name 'LineNumber' -Value ($Users.IndexOf($User) + 2)
                $User | Add-Member -MemberType NoteProperty -Name 'Issue' -Value 'MobileNumber'
                $InvalidUsers += $User
                continue
            }
            if ($User.RSA -notin @('true', 'false', '')) {
                $Script:DataValidated = $false
                $User | Add-Member -MemberType NoteProperty -Name 'LineNumber' -Value ($Users.IndexOf($User) + 2)
                $User | Add-Member -MemberType NoteProperty -Name 'Issue' -Value 'RSA'
                $InvalidUsers += $User
                continue
            }
            if ($User.RSA -eq 'true' -and ([string]::IsNullOrWhiteSpace($User.PhoneType) -or $User.PhoneType -notin @('Android', 'iPhone'))) {
                $Script:DataValidated = $false
                $User | Add-Member -MemberType NoteProperty -Name 'LineNumber' -Value ($Users.IndexOf($User) + 2)
                $User | Add-Member -MemberType NoteProperty -Name 'Issue' -Value 'PhoneType'
                $InvalidUsers += $User
                continue
            }
        }
        if ($InvalidUsers.Count -gt 0) {
            if ($PSBoundParameters.Keys -contains 'UserFile') {
                Write-InformationPlus "There are data issues found in the data file $UserFile." -ForegroundColor Red
                Write-InformationPlus "Please check the flagged data:`n" -ForegroundColor Red
            }
            else {
                Write-InformationPlus "There are data issues with the provided parameters." -ForegroundColor Red
                Write-InformationPlus "Please check the data:`n" -ForegroundColor Red
            }
            # if output is request as a variable do not format it.
            if ($PSBoundParameters.Keys -contains 'OutVariable') {
                $InvalidUsers
            }
            else {
                $InvalidUsers | Format-Table LineNumber, Issue, FirstName, LastName, Description, EmailAddress, MobileNumber, ADGroups, AADGroups, RSA, PhoneType -Wrap -AutoSize
            }
            Format-Error -e [System.Exception]::new('New-ADUser failed due to data input issues.')
        }

        # Need to fix
        # Login to Azure AD
        # Connect-AzureADTenant -AADTenant $Domain

        foreach ($User in $Users) {

            Clear-Variable Password, fn, fnid, ln, lnid, SecurePW, UserADGroups, UserAADGroups, UserProperties, SecretKey, ADUser, Group -ErrorAction SilentlyContinue

            Write-InformationPlus "Processing user $($User.FirstName) $($User.LastName)"  -ForegroundColor Green

            # Only used for account creation
            $Password = New-Password

            Write-Debug "Password: $Password"

            # Set variables and lower case names for user creation
            $fn = $User.FirstName
            $fnid = $User.FirstName.ToLower().Replace(' ', '')
            $ln = $User.LastName
            $lnid = $User.LastName.ToLower().Replace(' ', '')

            # Add properties to be used later
            $User | Add-Member -MemberType NoteProperty -Name 'userid' -Value "$fnid.$lnid"
            $User | Add-Member -MemberType NoteProperty -Name 'UserPrincipalName' -Value "$fnid.$lnid@example.com"

            $SecurePW = ConvertTo-SecureString -String $Password -AsPlainText -Force

            # Split groups into an array
            if (-not [string]::IsNullOrWhiteSpace($User.ADGroups)) {
                Write-Verbose "Splitting ADGroups into an array: $($User.ADGroups)"
                $User.ADGroups = $User.ADGroups -split ';'
            }
            if (-not [string]::IsNullOrWhiteSpace($User.AADGroups)) {
                Write-Verbose "Splitting ADGroups into an array: $($User.AADGroups)"
                $User.AADGroups = $User.AADGroups -split ';'
            }

            # Set New-ADUser Properties
            $UserProperties = @{
                Name                  = "$fn $ln"
                SamAccountName        = $User.userid
                UserPrincipalName     = $User.UserPrincipalName
                AccountPassword       = $SecurePW
                GivenName             = $fn
                Surname               = $ln
                MobilePhone           = $User.MobileNumber
                Description           = $User.Description
                Path                  = 'ou=Users,dc=domain,dc=com'
                Enabled               = $true
                ChangePasswordAtLogon = $true
            }
            [array]$User.ADGroups += 'MFA', 'AADP2', 'SSPR'

            try {
                New-ADUser @UserProperties
                Write-Verbose "User $($User.FirstName) $($User.LastName) created successfully"
            }
            catch {
                Write-InformationPlus -Message "Unable to create user $($User.FirstName) $($User.LastName)" -ForegroundColor Red
                Write-InformationPlus -Message $_.Exception.Message -ForegroundColor Yellow
                $User | Add-Member -MemberType NoteProperty -Name 'Issue' -Value $_.Exception.Message
                $FailedUsers += $User
                # Stop processing for this user
                Continue
            }


            if (-not [string]::IsNullOrWhiteSpace($User.ADGroups)) {
                # Loop to wait for user to appear in AD
                # We do not expect an error here since the user has to be created to get this far.
                Do {
                    try {
                        $ADUser = Get-ADUser $User.userid
                    }
                    catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
                        # Do nothing, we are waiting for the ID to be created
                        Start-Sleep -Seconds 5
                        Write-Debug "Waiting for user to be created."
                    }
                    catch {
                        Write-InformationPlus "Could not find user to add groups, adding to failed users." -ForegroundColor Red
                        $User | Add-Member -MemberType NoteProperty -Name 'Issue' -Value $_.Exception.Message
                        $FailedUsers += $User
                        break
                    }
                } Until ($ADUser)
                    
                if ($ADUser) {
                    foreach ($Group in $User.ADGroups) {
                        if (-not [string]::IsNullOrEmpty($Group)) {
                            try {
                                Write-Verbose "Proccessing AD group $Group"
                                Add-ADGroupMember -Identity $Group -Members $ADUser
                            }
                            catch {
                                Write-InformationPlus "Unable to add user to $Group, adding to failed users."  -ForegroundColor Red
                                $User | Add-Member -MemberType NoteProperty -Name 'Issue' -Value $_.Exception.Message
                                $FailedUsers += $User
                                # Exit group loop
                                break
                            }
                        }
                    }
                }

            } # End Add ADGroup membership

            # the two previous loops require us to check $FailedUsers for the current User
            # because a continue in an inner loop would not have continued the outer loop
            if ($FailedUsers -contains $User) {
                continue
            }

            $CreatedUsers += $User
    
        } # End $Users loop

        # if no user where created, exit function
        if ($CreatedUsers.Count -eq 0) {
            Exit-Function $PSBoundParameters
            return 'No Users Created'
        }

        # Sync users with Azure AAD.
        
        Write-InformationPlus 'Syncing with AzureAD' -NoNewline -ForegroundColor Green
        # Setup variables
        $Start = Get-Date
        $ADCServer = "VM-PRDFHTADC01"
        $Tenant = "Tenant.onmicrosoft.com - AAD"
        $ManualSync = $false

        $CimParams = @{
            "ComputerName" = $ADCServer
            "Class"        = "MIIS_RunHistory"
            "Namespace"    = "root\MicrosoftIdentityIntegrationServer"
            "Filter"       = "RunProfile = 'Export' AND MaName = '$Tenant'"
        }

        try {
            # Start AAD Sync process
            Invoke-Command -ComputerName $ADCServer -ScriptBlock {
                Do {
                    try {
                        $result = $null
                        $result = Start-ADSyncSyncCycle -PolicyType Delta
                    }
                    catch {
                        Start-Sleep -Seconds 10
                    }
                } until ($result.result -eq 'Success') 
            } | Out-Null
        }
        catch {
            $ManualSync = $true
            Write-InformationPlus 'FAILED!' -ForegroundColor Red
            Write-Verbose $_.Exception.Message
            Get-Input -Prompt "Unable to automatically sync with AAD. Please do this manually then type 'yes' to continue." -ValidResponses 'yes'
        }
        if (-not $ManualSync) {
            # Wait for sync to complete
            try {
                Do {
                    Write-InformationPlus '.' -NoNewline -ForegroundColor Green
                    $RunHistory = Get-CimInstance @CimParams -Verbose:$false
                    $LastRun = $RunHistory | Sort-Object RunEndTime -Descending | Select-Object -First 1
                    If ($LastRun.RunEndTime -ne 'in-progress') {
                        #Populate '$End' and convert to local time
                        $End = (Get-Date ($LastRun.RunEndTime)).ToLocalTime()
                    }
                    Else {
                        $End = "0"
                    }
                    #Throttle Get-CimInstance
                    Start-Sleep -Seconds 2
                } While ($End -lt $Start)
                Write-InformationPlus "`nSync completed." -ForegroundColor Green
            }
            catch {
                Write-InformationPlus 'Unable to check status!' -ForegroundColor Yellow
                Write-Verbose $_.Exception.Message
                Get-Input -Prompt "Please manually confirm the user(s) has been synced then type 'yes' to continue." -ValidResponses 'yes'
            }
        }

        # Process created users
        # Add any AADGroups to users
        # Send email notifications
        foreach ($User in $CreatedUsers) {
            Write-Verbose "Processing user $($User.FirstName) $($User.LastName)"
            Do {
                $UserFound = $null
                $UserFound = Get-AzADUser -UserPrincipalName $User.UserPrincipalName
                if (-not $UserFound) { Start-Sleep -Seconds 5 }
            } Until ($UserFound)
            foreach ($Group in $User.AADGroups) {
                if (-not [string]::IsNullOrEmpty($Group)) {
                    try {
                        Write-Verbose "Processing AAD group $Group."
                        Add-AzADGroupMember -MemberUserPrincipalName $User.UserPrincipalName -TargetGroupDisplayName $Group
                    }
                    catch {
                        Write-InformationPlus "Unable to add user $($User.UserPrincipalName) to $Group in Azure AD." -ForegroundColor Red
                        Write-InformationPlus "You will need to add this group manually." -ForegroundColor Red
                    }
                }
            }

            Write-Verbose "User email: $($User.EmailAddress)"
            Send-Email -To $User.EmailAddress -From 'Help Desk <helpdesk@example.com>' -Subject "$Domain Account" -TemplateName 'HT_AAD_Account' -TokenReplacement @{'#FIRSTNAME#' = $User.FirstName; '#USERID#' = $User.userid }
            
            # Check to see if value is 'true' for CSV or $true for parameters
            if ($User.RSA -eq 'true') {
                Write-Verbose "Sending RSA request."
                Send-Email -To 'security@example.com' -From 'Help Desk <helpdesk@example.com>' -Subject "New $Domin RSA Token" -TemplateName 'RSA_Request' -TokenReplacement @{'#DOMAIN#' = $Domain; '#USERID#' = $User.userid; '#PHONETYPE#' = $User.PhoneType }
            }

        } # End $CreatedUsers loop

        Exit-Function $PSBoundParameters

    }

    <#
    .SYNOPSIS
        New-ADUser is designed to make creating users faster and more consistent.

    .PARAMETER Domain
        The domain of the user you are adding. 

    .PARAMETER FirstName
        First name of the user.  AD property GivenName

    .PARAMETER LastName
        Last name of the user.  AD property Surname

    .PARAMETER EmailAddress
        Email address of the user.

    .PARAMETER Description
        Description of the user. AD property Description

    .PARAMETER ADGroups
        Any AD groups the user should be a member of.  Groups should be provided as an array - @('Group1','Group2')
        
    .PARAMETER AADGroups
        Any Azure AD groups the user should be a member of.  Groups should be provided as an array - @('Group1','Group2')

    .PARAMETER MobileNumber
        User's mobile number. AD property MobilePhone
        Numbers should be entered like this:
            +1 555-444-1234

    .PARAMETER SourceUser
        SAMAccountName or UserPrincipalName of a user to copy groups from.

    .PARAMETER RSA
        This switch parameter indicates the user will need an RSA token for RDP access to servers.
        When set the user will also require the PhoneType parameter and an email will be sent to the Security team for the token.

    .PARAMETER PhoneType
        This is either Android or iPhone and is used for the RSA soft token type.

    .PARAMETER UserFile
        This is a file that can be used to bulk create users.

    .EXAMPLE
        PS> New-ADUser -FirstName 'Nancy' -LastName 'Drew' -EmailAddress 'nancy.drew@example.com' -Description 'Some Description' -PhoneType iPhone -RSA

        Create new user from command line (With RSA request)

    .EXAMPLE
        PS> New-ADUser -FirstName 'Nancy' -LastName 'Drew' -EmailAddress 'nancy.drew@example.com' -Description 'Some Description'

        Create new user from command line (No RSA request)

    .EXAMPLE
        PS> New-ADUser -FirstName 'Nancy' -LastName 'Drew' -EmailAddress 'nancy.drew@example.com' -Description 'Some Description' -ADGroups @('ADGroup1','ADGroup2') -AADGroups @('AADGroup1','AADGroup2')

        Create new user from command line (Specify groups, No RSA request)

    .EXAMPLE
        PS> New-ADUser -FirstName 'Nancy' -LastName 'Drew' -EmailAddress 'nancy.drew@example.com' -Description 'Some Description' -SourceUser 'joe.hardy@example.com'

        Create new user from command line (Copy groups from SourceUser)

    .EXAMPLE
        PS> Get-Content users.csv
        FirstName,LastName,Description,EmailAddress,ADGroups,AADGroups,RSA,PhoneType,MobileNumber
        Joe,Hardy,Test User,joe.hardy@example.com,,,,,+1 555-444-1234
        Nancy,Drew,Test User,nancy.drew@example.com,,,,,+1 555-444-5678
        ...

        PS> New-ADUser -UserFile users.csv

        Create new users from a file

    .EXAMPLE
        PS> Get-Content users.csv
        FirstName,LastName,Description,EmailAddress,ADGroups,AADGroups,RSA,PhoneType,MobileNumber
        Joe,Hardy,Test User,joe.hardy@example.com,ADGroup1;ADGroup2,AADGroup1;AADGroup2,,,+1 555-444-1234
        Nancy,Drew,Test User,nancy.drew@example.com,ADGroup1;ADGroup2,AADGroup3;AADGroup4,,,+1 555-444-5678
        ...

        PS> New-ADUser -UserFile users.csv

        Create new users from a file (Specify Groups)

    .EXAMPLE
        PS> Get-Content users.csv
        FirstName,LastName,Description,EmailAddress,ADGroups,AADGroups,RSA,PhoneType,MobileNumber
        Joe,Hardy,Test User,joe.hardy@example.com,,,true,iPhone,+1 555-444-1234
        Nancy,Drew,Test User,nancy.drew@example.com,,,true,Android,+1 555-444-5678
        ...
        
        PS> New-ADUser -UserFile <path>\users.csv
        
        Create new users from a file (With RSA)

    .LINK
    PS-Tools Project URL
        https://github.com/scott1138/ps-tools
    #>
}