function Remove-AzAppGwConfig {

    [CmdletBinding(SupportsShouldProcess=$True)]

    param (

        [Parameter(Mandatory = $true)]
        [string]
        $RGName,

        [Parameter(Mandatory = $true)]
        [string]
        $AppGwName

    )

    begin {}

    process {
        $WarningPreference = 'SilentlyContinue'

        # Get App Gateway
        Write-InformationPlus -Message "Getting Application Gateway $AppGWName..." -NoNewLine
        try {
            $AppGW = Get-AzApplicationGateway -ResourceGroupName $RGName -Name $AppGWName
            Write-InformationPlus -Message "Done!" -ForegroundColor Green
        }
        catch {
            Write-InformationPlus "Error!" -ForegroundColor Red
            Format-Error -e $_ -Message 'Failed to get Application Gateway'
        }

        $Changes = @()

        Write-InformationPlus -Message "Processing Request Routing Rules..."
        $Items = Get-AzApplicationGatewayRequestRoutingRule -ApplicationGateway $AppGW
        foreach ($Item in $Items) {
            $Response = Get-Input -Prompt "Do you want to remove $($Item.Name)?" -Default 'N' -ValidResponses @('Y','N')
            if ($Response -eq 'Y') {
                Remove-AzApplicationGatewayRequestRoutingRule -ApplicationGateway $AppGW -Name $Item.Name | Out-Null
                $Changes += $Item.Name
            }
        }

        Write-InformationPlus -Message "Processing Redirect Configurations..."
        $Items = Get-AzApplicationGatewayRedirectConfiguration -ApplicationGateway $AppGW
        foreach ($Item in $Items) {
            $Response = Get-Input -Prompt "Do you want to remove $($Item.Name)?" -Default 'N' -ValidResponses @('Y','N')
            if ($Response -eq 'Y') {
                Remove-AzApplicationGatewayRedirectConfiguration -ApplicationGateway $AppGW -Name $Item.Name | Out-Null
                $Changes += $Item.Name
            }
        }

        Write-InformationPlus -Message "Processing HTTP Listeners..."
        $Items = Get-AzApplicationGatewayHttpListener -ApplicationGateway $AppGW
        foreach ($Item in $Items) {
            $Response = Get-Input -Prompt "Do you want to remove $($Item.Name)?" -Default 'N' -ValidResponses @('Y','N')
            if ($Response -eq 'Y') {
                Remove-AzApplicationGatewayHttpListener -ApplicationGateway $AppGW -Name $Item.Name | Out-Null
                $Changes += $Item.Name
            }
        }

        Write-InformationPlus -Message "Processing Backend HTTP Settings..."
        $Items = Get-AzApplicationGatewayBackendHttpSetting -ApplicationGateway $AppGW
        foreach ($Item in $Items) {
            $Response = Get-Input -Prompt "Do you want to remove $($Item.Name)?" -Default 'N' -ValidResponses @('Y','N')
            if ($Response -eq 'Y') {
                Remove-AzApplicationGatewayBackendHttpSetting -ApplicationGateway $AppGW -Name $Item.Name | Out-Null
                $Changes += $Item.Name
            }
        }

        Write-InformationPlus -Message "Processing Custom Health Probes..."
        $Items = Get-AzApplicationGatewayProbeConfig -ApplicationGateway $AppGW
        foreach ($Item in $Items) {
            $Response = Get-Input -Prompt "Do you want to remove $($Item.Name)?" -Default 'N' -ValidResponses @('Y','N')
            if ($Response -eq 'Y') {
                Remove-AzApplicationGatewayProbeConfig -ApplicationGateway $AppGW -Name $Item.Name | Out-Null
                $Changes += $Item.Name
            }
        }

        # Confirm Changes and Execute
        Write-InformationPlus -Message "The following items will be removed!!!!" -ForegroundColor Yellow
        Write-InformationPlus -Message ($Changes -join "`n")
        $Response = Get-Input -Prompt "Do you want to continue (YES/NO)?" -Default 'NO' -ValidResponses @('YES','NO')
        if ($Response -eq 'YES') {
            Write-InformationPlus "`nCommitting Application Gateway changes..." -ForegroundColor Green
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
        }

    }

    end {}
}