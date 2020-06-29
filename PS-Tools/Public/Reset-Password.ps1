function Reset-Password {

    [CmdletBinding(SupportsShouldProcess=$True)]

    param (
        [Parameter(Mandatory=$true)]
        [string] $Username,

        [Parameter(Mandatory=$true)]
        [string] $Domain,

        [string] $EmailAddress,

        [int] $SecretTTL
    )

    if ($PSBoundParameters['Debug']) {
        $DebugPreference = 'Continue'
    }

    $ErrorActionPreference = 'Stop'


    $Password = New-Password

    Write-Verbose "Password: $Password"

    if ($SecretTTL) {
        $OneTimeSecretParams = @{
            Secret    = $Password
            SecretTTL = $SecretTTL
        }
    }
    else {
        $OneTimeSecretParams = @{
            Secret    = $Password
        }
    }

    $SecretKey = New-OneTimeSecret @OneTimeSecretParams

    $SecurePW = ConvertTo-SecureString -String $Password -AsPlainText -Force

    try{
        $ADUser = Get-ADUser $Username -Properties mail,EmailAddress,proxyAddresses
    }
    catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
        Format-Error -e $_ -Message 'User not found in Active Directory.'
    }
    catch {
        Format-Error -e $_ -Message 'Unknown error occurred validating user.'
    }
    
    try {
        Set-ADAccountPassword -Identity $Username -NewPassword $SecurePW -Reset
    }
    catch {
        Format-Error -e $_ -Message 'Unable to reset the password.'
    }

    # User default email address if none is provided.
    if ([string]::IsNullOrEmpty($EmailAddress)) {
        Write-Verbose "No email address provided."
        Write-Verbose "ADUser.mail`t`t`t$($ADUser.mail)"
        Write-Verbose "ADUser.EmailAddress`t`t$($ADUser.EmailAddress)"
        Write-Verbose "ADUser.proxyAddresses`t`t$($ADUser.proxyAddresses)"
        if (-not [string]::IsNullOrEmpty($ADUser.mail)) {
            Write-Verbose "Setting `$Email using ADUser mail property"
            $Email = $ADUser.mail
        }
        elseif (-not [string]::IsNullOrEmpty($ADUser.EmailAddress)) {
            Write-Verbose "Setting `$Email using ADUser EmailAddress property"
            $Email = $ADUser.EmailAddress
        }
        elseif ([boolean]($ADUser.proxyAddresses -cmatch 'SMTP:')) {
            Write-Verbose "Setting `$Email using ADUser proxyAddresses property"
            $Email = ($ADUser.proxyAddresses -cmatch 'SMTP').Replace('SMTP:','')
        }
        else {
            try{
                Throw 'No email address was found in AD for this user, please use the -EmailAddress parameter.'
            }
            catch {
                Format-Error -e $_
            }
        }
    }
    else {
        Write-Verbose "Using provided user email address"
        $Email = $EmailAddress
    }

    Send-Email -To $Email -From 'Help Desk <helpdesk@example.com>' -Subject "$Domain Account" -TemplateName 'New_Password' -TokenReplacement @{'#FIRSTNAME#'=$ADUser.GivenName;'#ONETIMESECRET#'=$SecretKey}

}