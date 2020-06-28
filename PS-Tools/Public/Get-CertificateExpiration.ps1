function Get-CertificateExpiration {
    
    [CmdletBinding(
        DefaultParameterSetName = 'Internal',
        SupportsShouldProcess = $True
    )]
    
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $ZoneName,

        [Parameter(
          ParameterSetName = 'Internal',
          Mandatory = $True
        )]
        [switch]
        $Internal,

        [Parameter(
          ParameterSetName = 'External',
          Mandatory = $True
        )]
        [switch]
        $External,

        [switch]
        $TestRun,

        [switch]
        $LogErrors

    )

    $ErrorActionPreference = 'Stop'

    if ($Internal) {
        try {
            $Hosts = Get-DnsServerResourceRecord -ComputerName 'DALPRDDOM01' -ZoneName $ZoneName |
                Where-Object {$_.HostName -ne '@' -and $_.RecordType -in @('A','CNAME')}
        }
        catch {
            Handle-Error -e $_ -Message 'Failed to retrieve DNS records'
        }
    }

    if ($External) {

    }

    # If TestRun switch is supplied, choose 20 random records
    $Hosts = $Hosts | Get-Random -Count 5

    # Thread safe variable to hold errors
    if ($LogErrors) {
        $Errors = [System.Collections.Concurrent.ConcurrentBag[object]]::new()
    }

    # Thread safe variable to hold the cert results
    $CertResults = [System.Collections.Concurrent.ConcurrentBag[object]]::new()

    Write-Verbose "$($Hosts.Count) records to process."

    # Run 40 concurrent threads to check each host 
    $Hosts | ForEach-Object -Throttle 40 -Parallel {

        # Set local verbose variable to use for console output
        if ($Using:VerbosePreference -eq 'Continue') {
            $VerboseSetting = $true
        }

        if ($Using:LogErrors) {
            $LocalErrors = $Using:Errors
        }

        Write-Verbose "Processing $($_.HostName)..." -Verbose:$VerboseSetting
        
        # Replace wildcard addresses with a valid host name for testing
        if (($_.HostName).Split('.')[0] -eq '*') {
            $Hostname = "$($_.Hostame.Replace('*','dummy')).$Using:ZoneName"
        }
        else {
            $Hostname = "$($_.HostName).$Using:ZoneName"
        }

        # Setup result variable within loop the references the main result variable
        $LocalCertResults = $Using:CertResults

        try {
            # Step 1 - Attempt to open a connection on port 443, failure will result in a 10061 error
            $Req = [System.Net.Sockets.TcpClient]::new($Hostname, '443')
            # Step 2 - Store the remote IP address - depending on DNS and redirects this could be different than the orginal record
            $IPAddress = $Req.Client.RemoteEndPoint.Address.IPAddressToString
            # Step 3 - Set up new stream, set RemoteCertificateValidationCallback to always be true - this avoids certificate validation errors
            $Stream = [System.Net.Security.SslStream]::new($Req.GetStream(), $false, ( { $True } -as [Net.Security.RemoteCertificateValidationCallback]))
            $Stream.AuthenticateAsClient($Hostname)
            # Step 4 - Make a web request to get some of the remote server information
            $Server = ((Invoke-WebRequest -Uri $Hostname -SkipCertificateCheck -ErrorAction SilentlyContinue).RawContent.Split("`n") | Where-Object {$_ -match 'Server'}).Split(':')[1].Trim()
            # Step 5 - Set up the properies hashtable
            # Note: the whois request helps us know where the cert is located: Azure, AWS, etc.
            $Properties = @{
                Hostname   = $Hostname
                IPAddress  = $IPAddress
                Server     = $Server
                IPOwner    = if ($Using:External) {(Invoke-RestMethod "http://whois.arin.net/rest/ip/$IPAddress" -Headers @{'Accept'='application/json'}).net.orgRef.'@name'} else {$null}
                Subject    = ($Stream.RemoteCertificate.Subject).Split(',')[0]
                Thumbprint = $Stream.RemoteCertificate.Thumbprint
                Expiration = [datetime]$Stream.RemoteCertificate.GetExpirationDateString()
            }
            # Step 6 - Create an object with the properties hashtable
            $CertResult = New-Object -TypeName psobject -Property $Properties | Select-Object Hostname, IPAddress, Server, IPOwner, Subject, Thumbprint, Expiration
            # Step 7 - Add the object to our local result variable
            $LocalCertResults.Add($CertResult)
        }
        catch [System.Net.Sockets.SocketException] {
            if ($_.Exception.GetBaseException().ErrorCode -eq '10061') {
                Write-Verbose "Connection Refused: $Hostname" -Verbose:$VerboseSetting
            }
            elseif ($_.Exception.GetBaseException().ErrorCode -eq '11001') {
                Write-Verbose "Host Not Found: $Hostname" -Verbose:$VerboseSetting
            }
            elseif ($_.Exception.GetBaseException().ErrorCode -eq '10060') {
                Write-Verbose "Connection Timeout: $Hostname" -Verbose:$VerboseSetting
            }
            else {
                Write-Verbose "Unknown Network Error: $Hostname" -Verbose:$VerboseSetting
                Write-Verbose "Socket Error Code: $($_.Exception.GetBaseException().SocketErrorCode)" -Verbose:$VerboseSetting
                Write-Verbose "Error Code: $($_.Exception.GetBaseException().Errorcode)" -Verbose:$VerboseSetting
            }
            if ($Using:LogErrors) {
                $Properties = @{
                    Hostname = $Hostname
                    Message = $_.Exception.GetBaseException().SocketErrorCode
                    ErrorCode = $_.Exception.GetBaseException().ErrorCode
                    Source = $_.Exception.GetBaseException().Source
                }
                $ErrorObject = New-Object -TypeName psobject -Property $Properties
                $LocalErrors.Add($ErrorObject)
            }
        }
        catch {
            Write-Verbose "Unexpected exception: $Hostname" -Verbose:$VerboseSetting
            Write-Verbose $_.Exception.Message -Verbose:$VerboseSetting
            if ($Using:LogErrors) {
                $Properties = @{
                    Hostname = $Hostname
                    Message = $_.Exception.GetBaseException().SocketErrorCode
                    ErrorCode = $_.Exception.GetBaseException().ErrorCode
                    Source = $_.Exception.GetBaseException().Source
                }
                $ErrorObject = New-Object -TypeName psobject -Property $Properties
                $LocalErrors.Add($ErrorObject)
            }
        }
        
    } # End of host loop

    Write-Output $CertResults

    if ($LogErrors) {
        $LogPath = "$env:TEMP\cert_exp_error_log.csv"
        $Errors | Select-Object HostName, Message, ErrorCode, Source |
            Export-CSV -NoTypeInformation -Path $LogPath
        Write-InformationPlus "Errors exported to $LogPath"
    }
}