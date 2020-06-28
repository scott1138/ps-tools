function New-AADServicePrincipal {

    [CmdletBinding(SupportsShouldProcess=$True)]

    param (
        [Parameter(Mandatory=$true)]
        [string] $Name,

        [switch] $CertAuth,

        [Parameter(Mandatory=$true)]
        [string]$AADTenant
    )

    $ErrorActionPreference = 'Stop'

    if ($PSBoundParameters['Debug']) {
        $DebugPreference = 'Continue'
    }

    # Connect to Azure and select subscription
    Write-Host "`nConnecting to Azure..." -NoNewLine
    Login-AzureAD -AADTenant $AADTenant
    Write-Host "Done!" -ForegroundColor Green

    # Install compatibility module for core
    # This is alpha, not sure if it works
    # Probably not needed with PS 7 improvements
    <#
    if ($PSEdition -eq 'Core') {
        try {
            if (-not (Get-InstalledModule -Name WindowsCompatibility)) {    
                Write-Verbose "Installing WindowsCompatibility module"
                Install-Module -Name WindowsCompatibility -Force
            }
            Import-Module WindowsCompatibility
            Import-WinModule PKI
        }
        catch {
            Handle-Error -e $_ -Message "Unable to install the WindowsCompatibility module. Resolve the issue and try again."
        }
    }
    #>

    # Check for Az module and warn if not installed
    try {
        if (Get-Module -Name Az -ListAvailable) {
            Import-Module Az
        }
        else {
            throw 'Required module Az is missing.  Please install before using New-AADServicePrincipal.'
        }
    }
    catch {
        Handle-Error -e $_
    }

    $AADProperties = @{
        DisplayName     = $Name
        IdentifierUris  = "http://$Name"
    }

    try {
        $AADApp = New-AzADApplication @AADProperties
    }
    catch {
        Handle-Error -e $_ -Message "Unable to create new AAD Application."
    }

    if ($CertAuth) {
        try {
            Get-ChildItem -Path Cert:\CurrentUser\My | Where-Object {$_.Subject -eq "CN=$Name"} | Remove-Item
        }
        catch {
            Handle-Error -e $_ -Message "Unable to clean up local certificate."
        }

        try {
            $Cert = New-SelfSignedCertificate -CertStoreLocation "cert:\CurrentUser\My" -Subject "CN=$Name" -KeySpec KeyExchange -KeyExportPolicy Exportable
            $CertValue = [System.Convert]::ToBase64String($cert.GetRawCertData())

            $AADCredential = @{
                ObjectId   = $AADApp.ObjectId
                CertValue  = $CertValue
                EndDate    = $Cert.NotAfter
                StartDate  = $Cert.NotBefore
            }
        }
        catch {
            Handle-Error -e $_ -Message "Unable to generate a new certificate."
        }

    }
    else {
        # Generate a complex password using an AES key
        try {
            $AESKey = New-Object Byte[] 32
            [Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($AESKey)
            $Base64Key = [System.Convert]::ToBase64String($AESKey)
            $Password = ConvertTo-SecureString -String $Base64Key -AsPlainText -Force

            $AADCredential = @{
                ObjectId   = $AADApp.ObjectId
                Password   = $Password
                EndDate    = (Get-Date).AddYears(1)
            }
        }
        catch {
            Handle-Error -e $_ -Message "Unable to generate a password."
        }
    }

    try {
        $AADPassword = New-AzADAppCredential  @AADCredential
    }
    catch {
        Handle-Error -e $_ -Message "Unable to create the AAD Application credential."
    }

    try {
        $AADSPN = New-AzADServicePrincipal -ApplicationId $AADApp.ApplicationId
    }
    catch {
        Handle-Error -e $_ -Message "Unable to create the AAD Service Principal."
    }

    $Output = New-Object PSObject -Property @{'ClientId'=$AADApp.ApplicationId}
    if ($CertAuth) {
        try {
            $Output | Add-Member -MemberType NoteProperty -Name 'CertThumbprint' -Value $Cert.Thumbprint
            $Password = Read-Host -Prompt "Cert PFX password" -AsSecureString
            if (!(Test-Path 'C:\Temp')) {New-Item -Type Directory -Path 'C:\Temp' | Out-Null}
            Export-PfxCertificate -Password $Password -Cert $Cert -FilePath "C:\Temp\$Name.pfx" -Force | Out-Null
            $Output | Add-Member -MemberType NoteProperty -Name 'CertificatePath' -Value "C:\Temp\$Name.pfx"
        }
        catch{
            Handle-Error -e $_ -Message "Unable to export certificate, it will need to be exported manually."
        }
    }
    else {
        $Output | Add-Member -MemberType NoteProperty -Name 'Password' -value $Base64Key
    }

    $Output
    
}