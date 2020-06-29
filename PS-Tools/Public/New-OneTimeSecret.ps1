function New-OneTimeSecret {

    [CmdletBinding(SupportsShouldProcess=$True)]

    param (
        # Providing this as a default for now, it allows access to the API, but nothing else
        #[Parameter(Mandatory=$true)]
        [string] $Username,

        # Providing this as a default for now, it allows access to the API, but nothing else
        # Validates an alphanumeric key
        #[Parameter(Mandatory=$true)]
        [ValidatePattern('^\w+$')]
        [string] $Key,

        [Parameter(Mandatory=$true)]
        [string] $Secret,

        # Secret life in hours, default is 4 hours.  Minimum is 1 hour, maximum is 24 hours.
        [ValidateRange(1,24)]
        [int] $SecretTTL = 4
    )

    # Convert minutes to seconds
    $SecretTTLString = ($SecretTTL * 360).ToString()

    $SecureKey = ConvertTo-SecureString -String $Key -AsPlainText -Force
    $Cred = New-Object pscredential($Username,$SecureKey)

    try {
        if ($PSCmdlet.ShouldProcess('***Secret***', 'Create one-time use URL')) {
            $Response = Invoke-WebRequest -Method Post -Credential $Cred -Uri 'https://onetimesecret.com/api/v1/share' -Form @{secret=$Secret;ttl=$SecretTTLString}
            $SecretKey = (ConvertFrom-Json $Response.Content).secret_key
        }
        return "https://onetimesecret.com/secret/$SecretKey"
    }
    catch {
        Format-Error -e $_ -Message "Unable to reach OneTimeSecret"
    }

}