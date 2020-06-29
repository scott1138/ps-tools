function New-SA {

  [CmdletBinding(
    DefaultParameterSetName = 'Prompt',
    SupportsShouldProcess = $True
  )]

  param (

    [Parameter(
      ParameterSetName = 'CmdLine',
      Mandatory = $true
    )]
    [ValidatePattern("^SA-(SBX|DEV|TST|TRN|UAT|PRD)([A-Z]{3}|SQL[0-9]{2})-\w{2,10}$")]
    [String] $UserName,

    [Parameter(
      ParameterSetName = 'CmdLine',
      Mandatory = $true
    )]
    [String] $Description,

    [Parameter(
      ParameterSetName = 'CmdLine',
      Mandatory = $true
    )]
    [ValidateSet("PRD","UAT","TRN","TST","DEV","SBX")]
    [String] $Environment,

    [Parameter(
      ParameterSetName = 'CmdLine'
    )]
    [Switch] $AzureSync,

    [Parameter(
      ParameterSetName = 'Prompt'
    )]
    [String] $Prompt

  )

  begin {
    $ErrorActionPreference = 'Stop'

    if ($PSBoundParameters['Debug']) {
      $DebugPreference = 'Continue'
    }

    # Set the domain controller
    try {
      # The [0] gets the first DC returned and makes it a string vs an AD object
      $DomainController = (Get-ADDomainController -Service PrimaryDC -Discover).HostName[0]
      if ([string]::IsNullOrEmpty($DomainController)) {
        throw 'No Domain Controller found!!'
      }
      Write-Verbose "Using domain controller $DomainController"
    }
    catch {
      Format-Error -e $_
    }


    # Array to hold accounts to be created
    $Accounts = @()

  }

  process {
    function Initialize-AccountDetails {
      param (
        [string] $Env
      )

      if ($AzureSync) {
        $BaseOU = 'OU=CloudSync,DC=Domain,DC=com'
      }
      else {
        $BaseOU = 'OU=Service Accounts,DC=Domain,DC=com'
      }

      switch ($Env) {
        {'P','PRD' -contains $_} {
          $Script:UserOU      = "OU=Production,$BaseOU"
          $Script:AcctEnv     = "PRD"
          $Script:SAGroup     = "Prod-ServiceAccounts"
        }
        {'U','UAT' -contains $_} {
          $Script:UserOU      = "OU=UAT,$BaseOU"
          $Script:AcctEnv     = "UAT"
          $Script:SAGroup     = "NonProd-ServiceAccounts"
        }
        {'T','TRN' -contains $_} {
          $Script:UserOU      = "OU=Training,$BaseOU"
          $Script:AcctEnv     = "TRN"
          $Script:SAGroup     = "NonProd-ServiceAccounts"
        }
        {'Q','TST' -contains $_} {
          $Script:UserOU      = "OU=QA-Test,$BaseOU"
          $Script:AcctEnv     = "TST"
          $Script:SAGroup     = "NonProd-ServiceAccounts"
        }
        {'D','DEV' -contains $_} {
          $Script:UserOU      = "OU=Development,$BaseOU"
          $Script:AcctEnv     = "DEV"
          $Script:SAGroup     = "NonProd-ServiceAccounts"
        }
        {'S','SBX' -contains $_} {
          $Script:UserOU      = "OU=Sandbox,$BaseOU"
          $Script:AcctEnv     = "SBX"
          $Script:SAGroup     = "NonProd-ServiceAccounts"
        }
      } # End Switch

    } # End Function Initialize-AccountDetails

    if ($PSCmdlet.ParameterSetName -eq 'Prompt') {
      Clear-Host
      # Walk user through account questions
      # Clear Variables
      Clear-Variable Description,UserOU,AcctEnv,SAGroup -ErrorAction SilentlyContinue

      # Select SA Environment
      Write-InformationPlus "Prod = P   UAT = U   Training = T   Test\QA = Q   Develoment = D   Sandbox = S"
      $EnvResponse = Get-Input -Prompt "What environment is this account for:" -ValidResponses @('P','U','T','Q','D','S')
    
      Initialize-AccountDetails -Env $EnvResponse

      # IsSQL Account
      $SQLResponse = Get-Input -Prompt 'Is the a SQL Server service account?' -Default 'N' -ValidResponses @('Y','N')

      if ($SQLResponse -eq 'Y') {

        $Instance = Get-Input -Prompt 'Enter the SQL Instance Number' -ValidResponses (1..99)
        # Convert instance to an int and format as a two character string
        $Instance = "{0:D2}" -f [int]$Instance

        Write-InformationPlus "`nChoose one or more of the following SQL account types:"
        Write-InformationPlus "A - SQL Server Database Engine"
        Write-InformationPlus "B - SQL Server Agent"
        Write-InformationPlus "C - SQL Server Reporting Services"
        Write-InformationPlus "D - SQL Server Analysis Services"
        Write-InformationPlus "E - SQL Server Integration Services`n"
        $SQLAcctTypes = Get-Input -Prompt 'Choose one or more of the SQL account types' -ValidResponses ('A','B','C','D','E') -MultipleChoice

        Write-InformationPlus "`n`n"
        $CSResponse = Get-Input -Prompt "Will the account(s) be synchronized with Azure"  -ValidResponses ('true','false') -Default 'false'

        $AzureSync = [System.Convert]::ToBoolean($CSResponse)

        foreach ($Selection in $SQLAcctTypes) {
          Switch ($Selection) {
            'A' {
                $SQLType = "SQLSrvr"
                $Description = "SQL Server service account for SQL Instance $Instance"
              }
            'B' {
                $SQLType = "SQLAgent"
                $Description = "SQL Agent service account for SQL Instance $Instance"
              }
            'C' {
                $SQLType = "SSRS"
                $Description = "SQL Service Reporting Services service account for SQL Instance $Instance"
              }
            'D' {
                $SQLType = "SSAS"
                $Description = "SQL Server Analysis Services service account for SQL Instance $Instance"
              }
            'E' {
                $SQLType = "SSIS"
                $Description = "SQL Server Integration Services service account for SQL Instance $Instance"
              }
          }

          $UserName = "SA-$($Script:AcctEnv)SQL$Instance-$SQLType"

          $UserProperties = @{
            UserName = $UserName
            Description = $Description
            UserOU = $Script:UserOU
            SAGroup = $Script:SAGroup
            AzureSync = $AzureSync
          }
          $Accounts += New-Object PSObject -Property $UserProperties
        } # End foreach SQLAcctTypes

      } # End SQL Section
      else {
        Write-InformationPlus "Please use the Service Account Naming Standard:"
        Write-InformationPlus "SA-<ENV><APP>-<PURPOSE>`n"
        Write-InformationPlus "Examples:"
        Write-InformationPlus "SA-DEVAPP-WFEAppPool"
        Write-InformationPlus "SA-PRDAPP-Monitoring`n"
        Write-InformationPlus "The <PURPOSE> should be relatable and between 2-10 characters"
        Write-InformationPlus "You may not exceed 20 total characters`n"
        $UserName = Get-Input -Prompt "Enter a username for the service account" -Match "^SA-(SBX|DEV|TST|TRN|UAT|PRD)([A-Z]{3})-\w{2,10}$" -MatchHint "Examples: SA-DEVAPP-AppPool, SA-PRDAPP-AzDevOps"

        Write-InformationPlus "`n`n"
        Write-InformationPlus "A description is required for all service acoounts."
        Write-InformationPlus "Please use the following format:"
        Write-InformationPlus "<ServerName(s)> - <Use Type> - <Actions performed>`n"
        Write-InformationPlus "Examples:"
        Write-InformationPlus "ServerName - Scheduled Task - Runs FTP job"
        Write-InformationPlus "ServerName - IIS App Pool - Runs the example.com site"
        $Description = Get-Input -Prompt "Enter a description for the account" -Required

        Write-InformationPlus "`n`n"
        $CSResponse = Get-Input -Prompt "Will this account be synchronized with Azure"  -ValidResponses ('true','false') -Default 'false'

        $AzureSync = [System.Convert]::ToBoolean($CSResponse)

        $UserProperties = @{
          UserName = $UserName
          Description = $Description
          UserOU = $Script:UserOU
          SAGroup = $Script:SAGroup
          AzureSync = $AzureSync
        }
        $Accounts += New-Object PSObject -Property $UserProperties
      } # End Non-SQL Section

    } # End if Prompt - Handles Prompted Accounts
    else {
      # Handles Command Line Account
      Initialize-AccountDetails -Env $Environment

      $UserProperties = @{
        UserName = $UserName
        Description =$Description
        UserOU = $Script:UserOU
        SAGroup = $Script:SAGroup
        AzureSync = $AzureSync
      }
      $Accounts += New-Object PSObject -Property $UserProperties
    } # End Else - Handles Command Line Account

    # Data validation
    Write-InformationPlus "`nThe following account will be created:"
    Write-Output ($Accounts | Format-Table UserName, Description, AzureSync -AutoSize)

    $null = Get-Input -Prompt 'Enter YES to continue or press Ctrl-C to exit' -ValidResponses 'Yes'

    # Create Accounts
    foreach ($Account in $Accounts) {
      Write-Verbose "Username:$($Account.UserName)"
      Write-Verbose "Path    :$($Account.UserOU)"
      Write-Verbose "SAGroup :$($Account.SAGroup)"
      $Password = New-Password
      $UserProperties = @{
        Name = $Account.UserName
        GivenName = 'SA'
        # The Surname is set to the rest of the Username after 'SA-'
        Surname = $Account.UserName.Split('-',2)[1]
        Description =$Account.Description
        SamAccountName = $Account.UserName
        UserPrincipalName = "$($Account.UserName)@example.com"
        EmailAddress = "$($Account.UserName)@example.com"
        Path = $Account.UserOU
        AccountPassword = (ConvertTo-SecureString -String $Password -AsPlainText -Force)
        Enable = $true
        PasswordNeverExpires = $true
        CannotChangePassword = $true
        Server = $DomainController
      }
      try {
        New-ADUser @UserProperties
        # Set Groups
        if ($PSCmdlet.ShouldProcess($Account.UserName, "Add to service account groups")) {
          Add-ADGroupMember -Server $DomainController -Identity 'BatchServiceLogon' -Members $Account.UserName
          Add-ADGroupMember -Server $DomainController -Identity $Account.SAGroup -Members $Account.UserName
          if ($Account.AzureSync) {
            Add-ADGroupMember -Server $DomainController -Identity 'NoMFA' -Members $Account.UserName
          }
        }
        # Wait for group membership confirmation
        $Script:SAGroupObj = Get-ADGroup -Server $DomainController -Identity $Account.SAGroup -Properties @("primaryGroupToken")
        # Get-ADUser doesn't have a -whatif parameter
        if ($PSCmdlet.ShouldProcess($Account.UserName, "Retrieve user and replace primary group token")) {
          Get-ADUser -Server $DomainController -Identity $Account.UserName | Set-ADUser -Server $DomainController -Replace @{primaryGroupID=$Script:SAGroupObj.primaryGroupToken}
        }
        # Wait for the primary group to change
        if ($PSCmdlet.ShouldProcess($Account.UserName, "Remove account from Domain Users group")) {
          Remove-ADGroupMember -Server $DomainController -Identity 'Domain Users' -Members $Account.UserName -Confirm:$false
        }
        # Output results
        Write-InformationPlus "Service Account $UserName created, the password is $Password"
        if ($Account.AzureSync) {
          Write-InformationPlus "IMPORTANT REQUIREMENT FOR AZURE SYNCED ACCOUNTS:"
          Write-InformationPlus "1. You must login as the account once to finish the Okta setup.  Please record the security question in the Secret Server notes."
          Write-InformationPlus "2. The NoMFA option only works on the internal network.  Connections coming from the internet (Azure) will need special consideration."
        }
      }
      catch {
        Format-Error -e $_ -Message "Failed to create user $($Account.UserName), aborting process!"
      }
    } # End Account Creation - foreach Account
        
  } # End Proccess 

  <#
  .SYNOPSIS

  .PARAMETER

  .EXAMPLE
    PS> 

  .LINK
    PS-Tools Project URL
    https://github.com/scott1138/ps-tools
  #>
}