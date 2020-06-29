function Set-AzAppGWConfig {
    
    [CmdletBinding(SupportsShouldProcess)]

    param (
        [Parameter(Mandatory=$true)]
        [string]$AADTenant,

        [Parameter(Mandatory = $true)]
        [string]$SubName,

        [Parameter(Mandatory = $true)]
        [string]$RGName,

        [Parameter(Mandatory = $true)]
        [string]$AppGWName,

        [Parameter(Mandatory = $true)]
        [string]$URL,

        [Parameter(Mandatory = $true)]
        [string]$AppName,

        [ValidateSet('Dev','Test','UAT','Training','Staging','NonProd','Prod')]
        [string]$Environment,

        [string[]]$BEPoolIP,

        [string[]]$BEPoolFQDN,

        [boolean]$RedirectHttp = $true,

        [string]$HttpProbePath,

        [string]$BEHttpCfgPort = '80',

        [string]$HttpsProbePath,

        [string]$BEHttpsCfgPort = '443',

        [ValidateSet('Enabled', 'Disabled')]
        [string]$CookieBasedAffinity = 'Disabled',

        [string]$AffinityCookieName = 'ApplicationGatewayAffinity',

        [string]$SSLCertName,

        [string]$SSLCertPath,

        [securestring] $SSLCertPassword,

        [string]$AuthCertName,

        [string]$AuthCertPath,

        [string]$HttpListenerPort = "80",

        [string]$HttpsListenerPort = "443"
    )

    begin {
        $ErrorActionPreference = 'Stop'

        if ($PSBoundParameters['Debug']) {
            $DebugPreference = 'Continue'
        }

        Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "true"
    }

    process {

        Write-InformationPlus ''

        # Capitalize the first letter of the environment
        # This is for Az Dev Ops pipelines where the env_name var has to be lower case
        # Because it is used in Azure names that do not accept capitals
        $Environment = (Get-Culture).TextInfo.ToTitleCase($Environment)

        # Set Default App Gateway component names
        $BEPoolName ="BEPool-$AppName-$Environment"
        
        # SSPCertPath is provided, HTTP redirect is enforced unless explicitly set to false.
        if ($SSLCertName) {
            Write-InformationPlus "Setting HTTPS resource names..." -NoNewLine
            $HttpsProbeName    = "Probe-$AppName-HTTPS-$Environment"
            $BEHttpsCfgName    = "BEHttp-$AppName-HTTPS-$Environment"
            $HttpsListenerName = "Listener-$AppName-HTTPS-$Environment"
            $HttpsRuleName     = "Rule-$AppName-HTTPS-$Environment"
            $HTTPS             = $true
            Write-InformationPlus "Done!" -ForegroundColor Green
        }
        
        # SSLCertName is provided but HTTP redirect is explicitly disabled 
        # OR
        # No SSLCertName is provided
        if (($SSLCertName -and -not $RedirectHttp) -or (-not $SSLCertName)) {
            Write-InformationPlus "Setting HTTP resource names..." -NoNewLine
            $HttpProbeName    = "Probe-$AppName-HTTP-$Environment"
            $BEHttpCfgName    = "BEHttp-$AppName-HTTP-$Environment"
            $HttpListenerName = "Listener-$AppName-HTTP-$Environment"
            $HttpRuleName     = "Rule-$AppName-HTTP-$Environment"
            $HTTP             = $true
            Write-InformationPlus "Done!" -ForegroundColor Green
        }

        # HTTP is redirected
        if ($RedirectHttp) {
            Write-InformationPlus "Setting Redirect resource names..." -NoNewLine
            $HttpRedirectName = "Redirect-$AppName-HTTP-$Environment"
            $HttpListenerName = "Listener-$AppName-HTTP-$Environment"
            $HttpRuleName     = "Rule-$AppName-HTTP-$Environment"
            Write-InformationPlus "Done!" -ForegroundColor Green
        }

        # Connect to Azure and select subscription
        Write-InformationPlus "`nConnecting to Azure..." -NoNewLine
        Connect-AzureADTenant -AADTenant $AADTenant
        Write-InformationPlus "Done!" -ForegroundColor Green
        
        # Set Subscription
        Set-AzContext -SubscriptionName $SubName | Out-Null

        # Get App Gateway
        Write-InformationPlus "Getting Application Gateway $AppGWName..." -NoNewLine
        try {
            $AppGW = Get-AzApplicationGateway -ResourceGroupName $RGName -Name $AppGWName
            Write-InformationPlus "Done!" -ForegroundColor Green
        }
        catch {
            Write-InformationPlus "Error!" -ForegroundColor Red
            Format-Error -e $_ -Message 'Failed to get Application Gateway'
        }

        # Get IP and Port info for configuration
        Write-InformationPlus "Getting IP resource..." -NoNewLine
        try {
            $FEIP = Get-AzApplicationGatewayFrontendIPConfig -ApplicationGateway $AppGW
            Write-InformationPlus "Done!" -ForegroundColor Green
        }
        catch {
            Write-InformationPlus "Error!" -ForegroundColor Red
            Format-Error -e $_ -Message 'Failed to get IP resource'
        }

        # Get HTTP Port info for configuration
        if ($HTTP -or $RedirectHttp) {
            Write-InformationPlus "Getting HTTP Port resources..." -NoNewLine
            try {
                $FEPortHttp = Get-AzApplicationGatewayFrontendPort -ApplicationGateway $AppGW | Where-Object { $_.Port -eq $HttpListenerPort }
                if ($null -eq $FEPortHttp) {
                    Write-InformationPlus "`nCreating port resource for port $HttpListenerPort..." -NoNewLine
                    Add-AzApplicationGatewayFrontendPort -ApplicationGateway $AppGW -Name "FEPort-$HttpListenerPort" -Port $HttpListenerPort | Out-Null
                    $FEPortHttp = Get-AzApplicationGatewayFrontendPort -ApplicationGateway $AppGW | Where-Object { $_.Port -eq $HttpListenerPort }
                }
                Write-InformationPlus "Done!" -ForegroundColor Green
            }
            catch {
                Write-InformationPlus "Error!" -ForegroundColor Red
                Format-Error -e $_ -Message 'Failed to get HTTP port resource'
            }
        }

        # Get HTTP Port info for configuration
        if ($HTTPS) {
            Write-InformationPlus "Getting HTTPS Port resource..." -NoNewLine
            try {
                $FEPortHttps = Get-AzApplicationGatewayFrontendPort -ApplicationGateway $AppGW | Where-Object { $_.Port -eq $HttpsListenerPort }
                if ($null -eq $FEPortHttps) {
                    if ($HttpsListenerPort -eq '443') {
                        Write-InformationPlus "`nAdding HTTPS Port resource..."  -NoNewLine
                        Add-AzApplicationGatewayFrontendPort -ApplicationGateway $AppGW -Name 'FEPort-HTTPS' -Port 443 | Out-Null
                    }
                    else {
                        Write-InformationPlus "`nCreating port resource for port $HttpsListenerPort..." -NoNewLine
                        Add-AzApplicationGatewayFrontendPort -ApplicationGateway $AppGW -Name "FEPort-$HttpsListenerPort" -Port $HttpsListenerPort | Out-Null
                    }
                    $FEPortHttps = Get-AzApplicationGatewayFrontendPort -ApplicationGateway $AppGW | Where-Object { $_.Port -eq '443' }
                }
                Write-InformationPlus "Done!" -ForegroundColor Green
            }
            catch {
                Write-InformationPlus "Error!" -ForegroundColor Red
                Format-Error -e $_ -Message 'Failed to get HTTPS port resource'
            }
        
            Write-InformationPlus "`nStarting config for $URL...`n"

            # Add and get new ssl and auth certs
            try {
                Write-InformationPlus "Processing SSL Certificate..." -NoNewLine
                $SSLCert = Get-AzApplicationGatewaySslCertificate -Name $SSLCertName -ApplicationGateway $AppGW -ErrorAction SilentlyContinue
                if ($null -eq $SSLCert -and [boolean]$SSLCertPath) {
                    Write-InformationPlus "`n  Adding SSL Certificate..." -NoNewLine
                    if (-not $SSLCertPassword) {
                        $SSLCertPassword = Read-Host -Prompt "Enter the password for $SSLCertName" -AsSecureString
                    }
                    Add-AzApplicationGatewaySslCertificate -Name $SSLCertName -CertificateFile $SSLCertPath -Password $SSLCertPassword -ApplicationGateway $AppGW | Out-Null
                    $SSLCert = Get-AzApplicationGatewaySslCertificate -Name $SSLCertName -ApplicationGateway $AppGW
                    Write-InformationPlus "Done!" -ForegroundColor Green
                }
                elseif ([boolean]$SSLCert -and [boolean]$SSLCertPath) {
                    Write-InformationPlus "`n  Updating SSL Certificate..." -NoNewLine
                    if (-not $SSLCertPassword) {
                        $SSLCertPassword = Read-Host -Prompt "Enter the password for $SSLCertName" -AsSecureString
                    }
                    Set-AzApplicationGatewaySslCertificate -Name $SSLCertName -CertificateFile $SSLCertPath -Password $SSLCertPassword -ApplicationGateway $AppGW | Out-Null
                    $SSLCert = Get-AzApplicationGatewaySslCertificate -Name $SSLCertName -ApplicationGateway $AppGW
                    Write-InformationPlus "Done!" -ForegroundColor Green
                }
                elseif ($null -eq $SSLCert -and -not [boolean]$SSLCertPath) {
                    Write-InformationPlus "Error!" -ForegroundColor Red
                    throw "No SSL Certificate found and no path provided!"
                }
                else {
                    Write-InformationPlus "Done!" -ForegroundColor Green
                }
            }
            catch {
                Write-InformationPlus "Error!" -ForegroundColor Red
                Format-Error -e $_ -Message 'Failed to process the SSL certificate'
            }
            try {
                Write-InformationPlus "Processing Auth Certificate..." -NoNewLine
                $AuthCert = Get-AzApplicationGatewayAuthenticationCertificate -Name $AuthCertName -ApplicationGateway $AppGW -ErrorAction SilentlyContinue
                if ($null -eq $AuthCert -and [boolean]$AuthCertPath) {
                    Write-InformationPlus "`n  Adding Auth Certificate..." -NoNewLine
                    Add-AzApplicationGatewayAuthenticationCertificate -Name $AuthCertName -CertificateFile $AuthCertPath -ApplicationGateway $AppGW | Out-Null
                    $AuthCert = Get-AzApplicationGatewayAuthenticationCertificate -Name $AuthCertName -ApplicationGateway $AppGW
                    Write-InformationPlus "Done!" -ForegroundColor Green
                }
                elseif ([boolean]$AuthCert -and [boolean]$AuthCertPath) {
                    Write-InformationPlus "`n  Updating Auth Certificate..." -NoNewLine
                    Set-AzApplicationGatewayAuthenticationCertificate -Name $AuthCertName -CertificateFile $AuthCertPath -ApplicationGateway $AppGW | Out-Null
                    $AuthCert = Get-AzApplicationGatewayAuthenticationCertificate -Name $AuthCertName -ApplicationGateway $AppGW
                    Write-InformationPlus "Done!" -ForegroundColor Green
                }
                elseif ($null -eq $AuthCert -and -not [boolean]$AuthCertPath) {
                    Write-InformationPlus "Error!" -ForegroundColor Red
                    throw "No Auth Certificate found and no path provided!"
                }
                else {
                    Write-InformationPlus "Done!" -ForegroundColor Green
                }
            }
            catch {
                Write-InformationPlus "Error!" -ForegroundColor Red
                Format-Error -e $_ -Message 'Failed to process the Auth certificate'
            }
        }

        # Add and get custom health probes
        Write-InformationPlus "Processing custom Health Probes..." -NoNewLine
        try {
            if ($HTTP) {
                $HttpProbe = Get-AzApplicationGatewayProbeConfig -Name $HttpProbeName -ApplicationGateway $AppGW -ErrorAction SilentlyContinue
                if ($null -eq $HttpProbe) {
                    Write-InformationPlus "`n  Adding HTTP Probe..." -NoNewLine
                    If (-not [boolean]$HttpProbePath) { $HttpProbePath = '/' }
                    If (-not [boolean]$HttpProbeURL) { $HttpProbeURL = $URL }
                    Add-AzApplicationGatewayProbeConfig -Name $HttpProbeName -Protocol Http -HostName $HttpProbeURL -Path $HttpProbePath -Interval 30 -Timeout 30 -UnhealthyThreshold 3 -ApplicationGateway $AppGW | Out-Null    
                    $HttpProbe = Get-AzApplicationGatewayProbeConfig -Name $HttpProbeName -ApplicationGateway $AppGW
                    Write-InformationPlus "Done!" -ForegroundColor Green
                }
                else {
                    Write-InformationPlus "`n  Updating HTTP Probe..." -NoNewLine
                    If (-not [boolean]$HttpProbePath) { $HttpProbePath = '/' }
                    If (-not [boolean]$HttpProbeURL) { $HttpProbeURL = $URL }
                    Set-AzApplicationGatewayProbeConfig -Name $HttpProbeName -Protocol Http -HostName $HttpProbeURL -Path $HttpProbePath -Interval 30 -Timeout 30 -UnhealthyThreshold 3 -ApplicationGateway $AppGW | Out-Null    
                    $HttpProbe = Get-AzApplicationGatewayProbeConfig -Name $HttpProbeName -ApplicationGateway $AppGW
                    Write-InformationPlus "Done!" -ForegroundColor Green
                }
            }
            if ($HTTPS) {
                $HttpsProbe = Get-AzApplicationGatewayProbeConfig -Name $HttpsProbeName -ApplicationGateway $AppGW -ErrorAction SilentlyContinue
                if ($null -eq $HttpsProbe) {
                    Write-InformationPlus "`n  Adding HTTPS Probe..." -NoNewLine
                    If (-not [boolean]$HttpsProbePath) { $HttpsProbePath = '/' }
                    If (-not [boolean]$HttpsProbeURL) { $HttpsProbeURL = $URL }
                    Add-AzApplicationGatewayProbeConfig -Name $HttpsProbeName -Protocol Https -HostName $HttpsProbeURL -Path $HttpsProbePath -Interval 30 -Timeout 30 -UnhealthyThreshold 3 -ApplicationGateway $AppGW | Out-Null    
                    $HttpsProbe = Get-AzApplicationGatewayProbeConfig -Name $HttpsProbeName -ApplicationGateway $AppGW
                    Write-InformationPlus "Done!" -ForegroundColor Green
                }
                else {
                    Write-InformationPlus "`n  Updating HTTPS Probe..." -NoNewLine
                    If (-not [boolean]$HttpsProbePath) { $HttpsProbePath = '/' }
                    If (-not [boolean]$HttpsProbeURL) { $HttpsProbeURL = $URL }
                    Set-AzApplicationGatewayProbeConfig -Name $HttpsProbeName -Protocol Https -HostName $HttpsProbeURL -Path $HttpsProbePath -Interval 30 -Timeout 30 -UnhealthyThreshold 3 -ApplicationGateway $AppGW | Out-Null    
                    $HttpsProbe = Get-AzApplicationGatewayProbeConfig -Name $HttpsProbeName -ApplicationGateway $AppGW
                    Write-InformationPlus "Done!" -ForegroundColor Green
                }
            }
        }
        catch {
            Write-InformationPlus "Error!" -ForegroundColor Red
            Format-Error -e $_ -Message 'Failed to add or get custom Health Probes'
        }


        # Add an/or get a new backend pool
        Write-InformationPlus "Processing Backend Pool..." -NoNewLine
        try {
            $BEPool = Get-AzApplicationGatewayBackendAddressPool -Name $BEPoolName -ApplicationGateway $AppGW -ErrorAction SilentlyContinue
            if ($null -eq $BEPool) {
                Write-InformationPlus "`n  Adding Backend Pool..." -NoNewLine
                if ([boolean]$BEPoolFQDN) {
                    Add-AzApplicationGatewayBackendAddressPool -Name $BEPoolName -BackendFqdns $BEPoolFQDN -ApplicationGateway $AppGW | Out-Null
                }
                elseif ([boolean]$BEPoolIP) {
                    Add-AzApplicationGatewayBackendAddressPool -Name $BEPoolName -BackendIPAddresses $BEPoolIP -ApplicationGateway $AppGW | Out-Null
                }
                else {
                    Add-AzApplicationGatewayBackendAddressPool -Name $BEPoolName -BackendFqdns $URL -ApplicationGateway $AppGW | Out-Null
                }
                $BEPool = Get-AzApplicationGatewayBackendAddressPool -Name $BEPoolName -ApplicationGateway $AppGW
                Write-InformationPlus "Done!" -ForegroundColor Green
            }
            else {
                if ([boolean]$BEPoolFQDN) {
                    Write-InformationPlus "`n  Updating Backend Pool FQDN..." -NoNewLine
                    Set-AzApplicationGatewayBackendAddressPool -Name $BEPoolName -BackendFqdns $BEPoolFQDN -ApplicationGateway $AppGW | Out-Null
                    Write-InformationPlus "Done!" -ForegroundColor Green
                }
                elseif ([boolean]$BEPoolIP) {
                    Write-InformationPlus "`n  Updating Backend Pool IP..." -NoNewLine
                    Set-AzApplicationGatewayBackendAddressPool -Name $BEPoolName -BackendIPAddresses $BEPoolIP -ApplicationGateway $AppGW | Out-Null
                    Write-InformationPlus "Done!" -ForegroundColor Green
                }
                else {
                    Write-InformationPlus "No changes or updates!" -ForegroundColor Green
                }
                $BEPool = Get-AzApplicationGatewayBackendAddressPool -Name $BEPoolName -ApplicationGateway $AppGW
            }
        }
        catch {
            Write-InformationPlus "Error!" -ForegroundColor Red
            Format-Error -e $_ -Message 'Failed to add or get Address Pool'
        }

        # Add new http config
        Write-InformationPlus "Processing HTTP/HTTPS Settings..." -NoNewLine
        try {
            if ($HTTP) {
                $BEHttpCfg = Get-AzApplicationGatewayBackendHttpSetting -Name $BEHttpCfgName -ApplicationGateway $AppGW -ErrorAction SilentlyContinue
                if ($null -eq $BEHttpCfg) {
                    Write-InformationPlus "`n  Adding HTTP Config ..." -NoNewLine
                    Add-AzApplicationGatewayBackendHttpSetting -Name $BEHttpCfgName -Protocol Http -Port $BEHttpCfgPort -CookieBasedAffinity $CookieBasedAffinity -AffinityCookieName $AffinityCookieName -RequestTimeout 240 -Probe $HttpProbe -ApplicationGateway $AppGW | Out-Null    
                    $BEHttpCfg = Get-AzApplicationGatewayBackendHttpSetting -Name $BEHttpCfgName -ApplicationGateway $AppGW
                    Write-InformationPlus "Done!" -ForegroundColor Green
                } 
                else {
                    Write-InformationPlus "`n  Updating HTTP Config ..." -NoNewLine
                    Set-AzApplicationGatewayBackendHttpSetting -Name $BEHttpCfgName -Protocol Http -Port $BEHttpCfgPort -CookieBasedAffinity $CookieBasedAffinity -AffinityCookieName $AffinityCookieName -RequestTimeout 240 -Probe $HttpProbe -ApplicationGateway $AppGW | Out-Null    
                    $BEHttpCfg = Get-AzApplicationGatewayBackendHttpSetting -Name $BEHttpCfgName -ApplicationGateway $AppGW
                    Write-InformationPlus "Done!" -ForegroundColor Green
                }
            }
            if ($HTTPS) {
                $BEHttpsCfg = Get-AzApplicationGatewayBackendHttpSetting -Name $BEHttpsCfgName -ApplicationGateway $AppGW -ErrorAction SilentlyContinue
                if ($null -eq $BEHttpsCfg) {
                    Write-InformationPlus "`n  Adding HTTPS Config ..." -NoNewLine
                    Add-AzApplicationGatewayBackendHttpSetting -Name $BEHttpsCfgName -Protocol Https -Port $BEHttpsCfgPort -CookieBasedAffinity $CookieBasedAffinity -AffinityCookieName $AffinityCookieName -RequestTimeout 240  -AuthenticationCertificates $AuthCert -Probe $HttpsProbe -ApplicationGateway $AppGW | Out-Null
                    $BEHttpsCfg = Get-AzApplicationGatewayBackendHttpSetting -Name $BEHttpsCfgName -ApplicationGateway $AppGW
                    Write-InformationPlus "Done!" -ForegroundColor Green
                }
                else {
                    Write-InformationPlus "`n  Updating HTTPS Config ..." -NoNewLine
                    Set-AzApplicationGatewayBackendHttpSetting -Name $BEHttpsCfgName -Protocol Https -Port $BEHttpsCfgPort -CookieBasedAffinity $CookieBasedAffinity -AffinityCookieName $AffinityCookieName -RequestTimeout 240  -AuthenticationCertificates $AuthCert -Probe $HttpsProbe -ApplicationGateway $AppGW | Out-Null
                    $BEHttpsCfg = Get-AzApplicationGatewayBackendHttpSetting -Name $BEHttpsCfgName -ApplicationGateway $AppGW
                    Write-InformationPlus "Done!" -ForegroundColor Green
                }
            }
        }
        catch {
            Write-InformationPlus "Error!" -ForegroundColor Red
            Format-Error -e $_ -Message 'Failed to add HTTP/HTTPS Settings'
        }

        # Add and get listeners
        Write-InformationPlus "Processing HTTP/HTTPS Listeners..."
        try {
            if ($HTTPS) {
                $HttpsListener = Get-AzApplicationGatewayHttpListener -Name $HttpsListenerName -ApplicationGateway $AppGW -ErrorAction SilentlyContinue
                if ($null -eq $HttpsListener) {
                    Write-InformationPlus "  Adding HTTPS Listener..." -NoNewLine
                    Add-AzApplicationGatewayHttpListener -Name $HttpsListenerName -Protocol Https -FrontendIPConfiguration $FEIP -FrontendPort $FEPortHttps -HostName $URL -RequireServerNameIndication true -SslCertificate $SSLCert -ApplicationGateway $AppGW | Out-Null
                    $HttpsListener = Get-AzApplicationGatewayHttpListener -Name $HttpsListenerName -ApplicationGateway $AppGW
                    Write-InformationPlus "Done!" -ForegroundColor Green
                }
                else {
                    Write-InformationPlus "  Updating HTTPS Listener..." -NoNewLine
                    Set-AzApplicationGatewayHttpListener -Name $HttpsListenerName -Protocol Https -FrontendIPConfiguration $FEIP -FrontendPort $FEPortHttps -HostName $URL -RequireServerNameIndication true -SslCertificate $SSLCert -ApplicationGateway $AppGW | Out-Null
                    $HttpsListener = Get-AzApplicationGatewayHttpListener -Name $HttpsListenerName -ApplicationGateway $AppGW
                    Write-InformationPlus "Done!" -ForegroundColor Green
                }
            }
            
            if ($HTTP -or $RedirectHttp) {
                $HttpListener = Get-AzApplicationGatewayHttpListener -Name $HttpListenerName  -ApplicationGateway $AppGW -ErrorAction SilentlyContinue
                if ($null -eq $HttpListener) {
                    Write-InformationPlus "  Adding HTTP Listener..." -NoNewLine
                    Add-AzApplicationGatewayHttpListener -Name $HttpListenerName -Protocol Http -FrontendIPConfiguration $FEIP -FrontendPort $FEPortHttp -HostName $URL -ApplicationGateway $AppGW | Out-Null
                    $HttpListener = Get-AzApplicationGatewayHttpListener -Name $HttpListenerName  -ApplicationGateway $AppGW
                    Write-InformationPlus "Done!" -ForegroundColor Green
                }
                else {
                    Write-InformationPlus "  Updating HTTP Listener..." -NoNewLine
                    Set-AzApplicationGatewayHttpListener -Name $HttpListenerName -Protocol Http -FrontendIPConfiguration $FEIP -FrontendPort $FEPortHttp -HostName $URL -ApplicationGateway $AppGW | Out-Null
                    $HttpListener = Get-AzApplicationGatewayHttpListener -Name $HttpListenerName  -ApplicationGateway $AppGW
                    Write-InformationPlus "Done!" -ForegroundColor Green
                }
            }
        }
        catch {
            Write-InformationPlus "Error!" -ForegroundColor Red
            Format-Error -e $_ -Message 'Failed to add or get Listeners'
        }

        # Add and redirect config
        try {
            if ($RedirectHttp) {
                $RedirectConfig = Get-AzApplicationGatewayRedirectConfiguration -Name $HttpRedirectName -ApplicationGateway $AppGW -ErrorAction SilentlyContinue
                if ($null -eq $RedirectConfig) {
                    Write-InformationPlus "  Adding HTTP Redirect Config..." -NoNewLine
                    Add-AzApplicationGatewayRedirectConfiguration -Name $HttpRedirectName -RedirectType Permanent -TargetListener $HttpsListener -IncludePath $true -IncludeQueryString $true -ApplicationGateway $AppGW | Out-Null
                    $RedirectConfig = Get-AzApplicationGatewayRedirectConfiguration -Name $HttpRedirectName -ApplicationGateway $AppGW
                    Write-InformationPlus "Done!" -ForegroundColor Green
                }
                else {
                    Write-InformationPlus "  Updating HTTP Redirect Config..." -NoNewLine
                    Set-AzApplicationGatewayRedirectConfiguration -Name $HttpRedirectName -RedirectType Permanent -TargetListener $HttpsListener -IncludePath $true -IncludeQueryString $true -ApplicationGateway $AppGW | Out-Null
                    $RedirectConfig = Get-AzApplicationGatewayRedirectConfiguration -Name $HttpRedirectName -ApplicationGateway $AppGW
                    Write-InformationPlus "Done!" -ForegroundColor Green
                }
            }
        }
        catch {
            Write-InformationPlus "Error!" -ForegroundColor Red
            Format-Error -e $_ -Message 'Failed to add or get Redirect Configuration'
        }

        # Add routing rules
        Write-InformationPlus "`nProcessing Request Routing Rules..."
        try {
            if ($HTTPS) {
                $HttpsRule = Get-AzApplicationGatewayRequestRoutingRule -Name $HttpsRuleName -ApplicationGateway $AppGW -ErrorAction SilentlyContinue
                if ($null -eq $HttpsRule) {
                    Write-InformationPlus "  Adding HTTPS Routing Rule..." -NoNewLine
                    Add-AzApplicationGatewayRequestRoutingRule -Name $HttpsRuleName -RuleType Basic -HttpListener $HttpsListener -BackendHttpSettings $BEHttpsCfg -BackendAddressPool $BEPool -ApplicationGateway $AppGW | Out-Null
                    Write-InformationPlus "Done!" -ForegroundColor Green
                }
                else {
                    Write-InformationPlus "  Updating HTTPS Routing Rule..." -NoNewLine
                    Set-AzApplicationGatewayRequestRoutingRule -Name $HttpsRuleName -RuleType Basic -HttpListener $HttpsListener -BackendHttpSettings $BEHttpsCfg -BackendAddressPool $BEPool -ApplicationGateway $AppGW | Out-Null
                    Write-InformationPlus "Done!" -ForegroundColor Green
                }
            }
            if ($RedirectHttp) {
                $HttpRule = Get-AzApplicationGatewayRequestRoutingRule -Name $HttpRuleName -ApplicationGateway $AppGW -ErrorAction SilentlyContinue
                if ($null -eq $HttpRule) {
                    Write-InformationPlus "  Adding HTTP Routing Rule..." -NoNewLine
                    Add-AzApplicationGatewayRequestRoutingRule -Name $HttpRuleName -RuleType Basic -HttpListener $HttpListener -RedirectConfiguration $RedirectConfig -ApplicationGateway $AppGW | Out-Null
                    Write-InformationPlus "Done!" -ForegroundColor Green
                }
                else {
                    Write-InformationPlus "  Updating HTTP Routing Rule..." -NoNewLine
                    Set-AzApplicationGatewayRequestRoutingRule -Name $HttpRuleName -RuleType Basic -HttpListener $HttpListener -RedirectConfiguration $RedirectConfig -ApplicationGateway $AppGW | Out-Null
                    Write-InformationPlus "Done!" -ForegroundColor Green
                }
            }
            if ($HTTP) {
                $HttpRule = Get-AzApplicationGatewayRequestRoutingRule -Name $HttpRuleName -ApplicationGateway $AppGW -ErrorAction SilentlyContinue
                if ($null -eq $HttpRule) {
                    Write-InformationPlus "  Adding HTTP Routing Rule..." -NoNewLine
                    Add-AzApplicationGatewayRequestRoutingRule -Name $HttpRuleName -RuleType Basic -HttpListener $HttpListener -BackendHttpSettings $BEHttpCfg -BackendAddressPool $BEPool -ApplicationGateway $AppGW | Out-Null
                    Write-InformationPlus "Done!" -ForegroundColor Green
                }
                else {
                    Write-InformationPlus "  Updating HTTP Routing Rule..." -NoNewLine
                    Set-AzApplicationGatewayRequestRoutingRule -Name $HttpRuleName -RuleType Basic -HttpListener $HttpListener -BackendHttpSettings $BEHttpCfg -BackendAddressPool $BEPool -ApplicationGateway $AppGW | Out-Null
                    Write-InformationPlus "Done!" -ForegroundColor Green
                }
            }
        }
        catch {
            Write-InformationPlus "Error!" -ForegroundColor Red
            Format-Error -e $_ -Message 'Failed to add Request Routing Rule'
        }

        # Check for active operations
        Write-InformationPlus "`nChecking for active Application Gateway operations..." -NoNewLine
        $AllClear = $false
        Do {
            $Script:State = (Get-AzApplicationGateway -Name $AppGW.Name -ResourceGroupName $AppGW.ResourceGroupName).ProvisioningState
            if ($Script:State = 'Succeeded') {
                $AllClear = $true
                Write-InformationPlus "Done!" -ForegroundColor Green
            }
            else {
                Write-InformationPlus "." -NoNewLine
                Start-Sleep -Seconds 5
            }
        } Until ($AllClear)

        # Set Application Gateway
        Write-InformationPlus "`nCommitting Application Gateway changes..." -ForegroundColor Green
        Write-InformationPlus "-- This may take 10-30 minutes" -ForegroundColor Yellow
        try {
            $StartTime = Get-Date
            Set-AzApplicationGateway -ApplicationGateway $AppGW | Out-Null
            $EndTime = Get-Date
        }
        catch {
            Export-Clixml -Path "$Env:TEMP\appgw.xml" -InputObject $AppGw -Force
            Format-Error -e $_ -Message "Failed to commit Application Gateway changes. Check AppGw object at $Env:TEMP\appgw.xml."
        }

        Write-InformationPlus "Changes committed successfully!" -ForegroundColor Green
        $ExecTime = New-TimeSpan -Start $StartTime -End $EndTime
        $ExecMin  = $ExecTime.Minutes
        $ExecSec  = $ExecTime.Seconds
        Write-InformationPlus "Total Execution Time: $ExecMin minutes $ExecSec seconds."
        Write-InformationPlus "Completed config for $URL"
    }

    <#
        .SYNOPSIS

        Create new Application Gateway components in a single update, saving you lots of time!

        .DESCRIPTION

        Create new Application Gateway components.
        You can supply minimal data and the function will name components for you.
        Each component name may also be specified to re-use existing components such as back end pools or certificates

        .PARAMETER AADTenant

        The AAD Tenant to log into.

        .PARAMETER SubName

        REQUIRED - Name of the Subscription where the Application Gateway exists.

        .PARAMETER RGName

        REQUIRED - Name of the Resource Group where the Application Gateway exists.

        .PARAMETER AppGWName

        REQUIRED - Name of the Application to be configured.

        .PARAMETER URL

        REQUIRED - URL of the site to be configured.

        .PARAMETER AppName

        Name of the application you are creating the configuration for, e.g. CP3, Envision, OCC.
        When used without specific names for other components, those component names will be created for you.

        .PARAMETER Environment

        Name of the application environment.  Accepted values: 'Dev', 'Test', 'UAT', 'NonProd', 'Prod'
        When used without specific names for other components, those component names will be created for you.

        .PARAMETER BEPoolIP

        When supplied this value will take the place of the URL as the Backend Pool target.

        .PARAMETER BEPoolFQDN

        When supplied this value will will be the preferred value for the Backend Pool target and will override both the URL and Backend Pool parameters.
        
        .PARAMETER HttpProbePath

        Custom path for an Http Probe.  Sometimes need for APIs that don't return 200 from /.  e.g. /health, /healthz

        .PARAMETER HttpsProbePath

        Custom path for an Https Probe.  Sometimes need for APIs that don't return 200 from /.  e.g. /health, /healthz

        .PARAMETER BEHttpCfgPort

        Port number used to connect to a http backend.  Default is 80.

        .PARAMETER BEHttpsCfgPort

        Port number used to connect to a https backend.  Default is 443.

        .PARAMETER CookieBasedAffinity

        Does the backend pool require persistence.  Acceptable valuse are Enabled or Disabled.  Default is Disabled.

        .PARAMETER AffinityCookieName

        Name of the affinity cookie.  Default is 'ApplicationGatewayAffinity'

        .PARAMETER SSLCertName

        Name of the SSL certificate as it is stored in the Application Gateway (not the subject or alternative names).
        This certificate is used by listeners to encrypt incoming client connections.
        IMPORTANT!!!!
        You can use the same certificate for multiple listeners if needed.
        For certificates to be used across multiple listeners please use a descriptive name:
        SSLCert-Wildcard-Prod
        SSLCert-AppName-NonProd
        Default: "SSLCert-$AppName-$Environment"

        .PARAMETER SSLCertPath

        Local path to a PFX file.  You will be prompted for the password.

        .PARAMETER AuthCertName

        Name of the backend authentication certificate as it is stored in the Application Gateway (not the subject or alternative names).
        This certificate is used to validate the backend host and must match the backend host's SSL certificate.
        IMPORTANT!!!!
        You can use the same certificate for multiple backend settings if needed.
        For certificates to be used across multiple backend settings please use a descriptive name:
        AuthCert-Wildcard-Prod
        AuthCert-AppName-NonProd
        Default: "AuthCert-$AppName-$Environment"

        .PARAMETER AuthCertPath

        Local path to a CER file.

        .PARAMETER HttpListenerPort

        Port used to accept incoming http client connections.  Default is 80.

        .PARAMETER HttpsListenerPort

        Port used to accept incoming Https client connections.  Default is 443.

        .PARAMETER RedirectHttp

        Value used to determine whether or not http should be redirect to https for this configuration.  Default is true.

        .EXAMPLE

        Scenario 1 - Supply only minimal values for configuration:
        $Test_Params = 
        @{
            SubName           = 'AzSubscription'
            RGName            = 'RG-AzSubscription-SouthCentralUS-Networking'
            AppGWName         = 'WAF-AzSubscription-SouthCentralUS-NonProd'
            AppName           = 'SomeApp'
            Environment       = 'Dev'
            URL               = 'someapp.example.com'
            SSLCertPath       = 'C:\Temp\someapp_example_com.pfx'
            AuthCertPath      = 'C:\Temp\someapp_example_com.cer'
        }

        # Import Script into this session
        . .\Add-AzureAppGwConfig.ps1

        Add-AzureAppGwConfig @Test_Params

        .EXAMPLE
        
        Scenario 2 - Supply specific values for the backend ports:
        $Test_Params = 
        @{
            SubName           = 'AzSubscription'
            RGName            = 'RG-AzSubscription-SouthCentralUS-Networking'
            AppGWName         = 'WAF-AzSubscription-SouthCentralUS-NonProd'
            AppName           = 'SomeApp'
            Environment       = 'Dev'
            URL               = 'someapp.example.com'
            SSLCertPath       = 'C:\Temp\someapp_example_com.pfx'
            AuthCertPath      = 'C:\Temp\someapp_example_com.cer'
            BEHttpCfgPort     = 9004
            BEHttpsCfgPort    = 9005
        }

        # Import Script into this session
        . .\Add-AzureAppGwConfig.ps1

        Add-AzureAppGwConfig @Test_Params

        .EXAMPLE
        
        Scenario 3 - Supply the names of existing certificates:
        $Test_Params = 
        @{
            SubName           = 'AzSubscription'
            RGName            = 'RG-AzSubscription-SouthCentralUS-Networking'
            AppGWName         = 'WAF-AzSubscription-SouthCentralUS-NonProd'
            AppName           = 'SomeApp'
            Environment       = 'Test'
            URL               = 'someapp.example.com'
            SSLCertName       = 'SSLCert-SomeApp-NonProd'
            AuthCertName      = 'AuthCert-SomeApp-NonProd'
        }

        # Import Script into this session
        . .\Add-AzureAppGwConfig.ps1

        Add-AzureAppGwConfig @Test_Params

    #>

}
