function Login-AzureAD {

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
      $Response = Connect-AzAccount
      Write-Verbose "Successfully logged into $AADTenant AAD."
    }
    catch {
      Handle-Error -e $_ -Message "Unable to connect to Azure AD."
    }
  }

}