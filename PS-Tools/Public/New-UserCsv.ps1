function New-UserCsv {

    [CmdletBinding(SupportsShouldProcess=$True)]

    param (
        [string] $Path = "$pwd\user.csv"
    )

    $ErrorActionPreference = 'Stop'

    if ($PSBoundParameters['Debug']) {
        $DebugPreference = 'Continue'
    }

    # Select Option
    ###################################
    Clear-Host

    Do {
        $OptionSelected = $false
        Write-InformationPlus "Select an option:"
        Write-InformationPlus "  1. Create a CSV file with headers but no data."
        Write-InformationPlus "  2. Enter user data."
        Write-InformationPlus "  E. Exit"
        $Option = Read-Host  "----------------------------`n"
        switch ($Option) {
            '1' {$OptionSelected = $true}
            '2' {$OptionSelected = $true}
            'e' {Write-InformationPlus "User exited function.`n" -ForeGroundColor Yellow;return}
            default {Write-InformationPlus "`n$Option is an invalid selection!`nPlease choose an option from the menu.`n" -ForeGroundColor Yellow}
        }
    }
    Until ($OptionSelected)

    # Option 1 - Write Blank CSV
    ###################################
    if ($Option -eq '1') {
        'FirstName,LastName,Description,EmailAddress,MobileNumber,ADGroups,AADGroups,RSA,PhoneType' | Out-File -FilePath $Path
        $FullPath = (Get-Item $Path).FullName
        Write-InformationPlus "User CSV template created: $FullPath`n"
        return
    }


    # Option 2 - Populate User Data
    ###################################

    # Step 1 - Collect Data
    ###################################
    $Users = @()
    $Finished = $false
    Clear-Variable BaseUserName,BaseADUser,BaseADGroups -ErrorAction SilentlyContinue

    Do {
        Clear-Host
        Write-InformationPlus "User $($Users.Count + 1)`n"
        $CopyUserSuccess = $false
        $BaseADGroups = $null
        Do {
            if ([boolean](Get-Module -Name ActiveDirectory -ListAvailable -ErrorAction SilentlyContinue)) {
                if ((Get-Input -Prompt 'Copy this user from an existing user?' -ValidResponses @('y','n') -Default 'n') -eq 'y') {
                    $BaseUserName = Get-Input -Prompt 'Enter the user''s account name or email address' -Default $BaseUserName -Required
                    try {
                        $BaseADUser = Get-ADUser -filter {samaccountname -eq $BaseUserName -or mail -eq $BaseUserName} -Properties MemberOf
                        $BaseADGroups = ($BaseADUser.MemberOf | Foreach-Object {try{Get-ADGroup -Identity $_ | Select-Object -ExpandProperty Name}catch{}}) -join ';'
                        $CopyUserSuccess = $true
                    }
                    catch {
                        Write-InformationPlus "AD User $BaseUserName was not found, please try again."
                    }
                }
                else {
                    $CopyUserSuccess = $true
                }
            }
            else {
                Write-InformationPlus "Unable to copy a user, Active Directory module is not present.`n"
                break
            }
            Write-InformationPlus "`n"
        } Until ($CopyUserSuccess)

        $FirstName    = Get-Input -Prompt 'First Name (no special characters)' -Required
        $LastName     = Get-Input -Prompt 'Last Name (no special characters)' -Required
        $Description  = Get-Input -Prompt 'Description' -Required
        $EmailAddress = Get-Input -Prompt 'Email Address' -Default ("$FirstName.$LastName@example.com".ToLower()) -Required
        $ADGroups     = Get-Input -Prompt 'AD Groups (separate groups with a semi-colon(;)' -Default $BaseADGroups
        $MobileNumber = Get-Input -Prompt "Mobile phone number with country code:`n(example:+1 555-444-1234)" -Required
        $AADGroups    = Get-Input -Prompt 'Azure AD Groups (separate groups with a semi-colon(;) or leave blank for none)'

        $RSA = Get-Input -Prompt 'Will this user need an RSA token? (true,false)' -Default 'false' -ValidResponses @('true','false')
        if ($RSA -eq $true) {
            $PhoneType = Get-Input -Prompt 'PhoneType' -ValidResponses @('iPhone','Android')
        }
        
        
        $Properties = @{
            FirstName    = $FirstName
            LastName     = $LastName
            Description  = $Description
            EmailAddress = $EmailAddress
            ADGroups     = $ADGroups
            AADGroups    = $AADGroups
            RSA          = $RSA
            PhoneType    = $PhoneType
            MobileNumber = $MobileNumber
        }

        $Users += New-Object PSObject -Property $Properties

        $finished = if ((Get-Input -Prompt "`nAnother User?" -Default 'n' -ValidResponses @('y','n')) -eq 'n') {$true}

    } Until ($Finished)
    

    # Step 2 - Confirm Data
    ###################################
    $DataConfirmed = $false
    Do {
        Clear-Host
        $Users | Format-Table @{Name='Index';Expression={$Users.IndexOf($_)}},FirstName,LastName,Description,EmailAddress,MobileNumber,ADGroups,AADGroups,RSA,PhoneType -Wrap -AutoSize
        Write-InformationPlus "`n"
        #$Response = Get-Input -Prompt 'Choose an entry to edit or press C to continue' -ValidResponses @(0..($users.count-1),'c') -Default 'C'
        Write-InformationPlus "Press any key to write the data to $Path"
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        $DataConfirmed = $true
    } Until ($DataConfirmed)

    # Step 3 - Write Data
    ###################################
    try {
        $Users | Select-Object FirstName,LastName,Description,EmailAddress,MobileNumber,ADGroups,AADGroups,RSA,PhoneType | Export-Csv -NoTypeInformation -Path $Path
    }
    catch {
        Format-Error -e $_ -Message 'Failed to write user data to file.'
    }

    <#
    .SYNOPSIS
        The New-UserCsv cmdlet helps create a CSV file to be used with New-User.  The cmdlet will walk you through the values needed for each user.

    .PARAMETER Path
        The path and filename where the CSV will be output.  The default is user.csv in the current directory.  Any existing file will be over written.

    .EXAMPLE
        PS> New-UserCsv -Path c:\temp\user.csv

    .LINK
        PS-Tools Project URL
        https://github.com/scott1138/ps-tools
    #>
}