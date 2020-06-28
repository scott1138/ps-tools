function Connect-AzureADTenant {

  [CmdletBinding()]

  param (
    [string] $AADTenant
  )

  $ErrorActionPreference = 'Stop'

  $Login = $false

  $Context = Get-AzContext
  if ($null -eq $Context.Tenant.Id) {
    $Login = $True
  }
  else {
    Write-Verbose "Current user context: $($Context.Account.Id)"
    return
  }

  if ($Login) {
    try {
      Connect-AzAccount | Out-Null
      Write-Verbose "Successfully logged into $AADTenant AAD."
    }
    catch {
      Format-Error -e $_ -Message "Unable to connect to Azure AD."
    }
  }

}