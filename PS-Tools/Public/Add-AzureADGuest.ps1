#Requires -PSEdition Desktop
Function Add-AzureADGuest {
  [CmdletBinding()]

  Param
  (
    [Parameter(Mandatory)]
    [string]
    $EmailAddress,

    [string]
    $DisplayName
  )

  $ErrorActionPreference = 'Stop'

  # Connect to Azure AD
  Write-Information "Connecting to Azure AD..." 
  try {
    $AADSession = Get-AzureADCurrentSessionInfo
    Write-InformationPlus "Session already connected as $($AADSession.Account)" -ForegroundColor Green
  }
  catch {
    try {
      Connect-AzureAD -Credential (Get-Credential) | Out-Null
    }
    catch {
      Write-InformationPlus "Failed to connect to Azure AD" -ForegroundColor Red
      Write-InformationPlus $_.Exception.Message -ForegroundColor Yellow
    }
  } 
    
  if ($DisplayName) {
    New-AzureADMSInvitation -InvitedUserDisplayName $DisplayName -InvitedUserEmailAddress $EmailAddress -SendInvitationMessage $True -InviteRedirectUrl "http://myapps.onmicrosoft.com"        
  }
  else {
    New-AzureADMSInvitation -InvitedUserEmailAddress $EmailAddress -SendInvitationMessage $True -InviteRedirectUrl "http://myapps.onmicrosoft.com"
  }

  <#
    .SYNOPSIS
      New-ADUser is designed to make creating users faster and more consistent.

    .PARAMETER EmailAddress
      Required. Email Address of the guest user

    .PARAMETER DisplayName
      Optional. Display Name of the guest user

    .EXAMPLE
      Add-AzureADGuest -EmailAddress nancy.drew@anothercompany.com

    .LINK
    PS-Tools Project URL
        https://github.com/scott1138/ps-tools
  #>

} # End Function
