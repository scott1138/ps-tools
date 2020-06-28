# PS-Tools

PS-Tools is a collection of tools to simplify the administrative processes.

## Build Status
[![Build Status](https://dev.azure.com/scott-1138/scott1138/_apis/build/status/scott1138.ps-tools?branchName=master)](https://dev.azure.com/scott-1138/scott1138/_build/latest?definitionId=3&branchName=master)

** The Pester tests are having issues but the 'Fail if there are test failures' is set to false ** 

## NOTE: DOCUMENTATION IS CURRENTLY INCOMPLETE

## Table of Contents

* [Change Log](#Change-Log)
* [Requirements](#Requirements)
* [Commands](#Commands)
* [Examples](#Examples)
* [Pending Improvements](#Pending-Improvements)

## Change Log
* version 1.0.0 - 2020-06-24
  * Initial collection
  

## Requirements

To download the module, add the PowerShell Repository to your system.
```
Register-PSRepository -Name 'PS-Tools' -SourceLocation 'tbd'
```
Then install the module as usual.
```
Install-Module -Name PS-Tools
```
Several of the cmdlets require other modules be preset as well, including, but not limited to:
* Az

## Commands

* [New-AADServicePrincipal](#New-AADServicePrincipal)
  * Creates an Azure AD service principal.  Can use generate either a password or certificate to be used for authentication.
  * Outputs the client id and the password or certificate as a PFX.
* [New-ADUser](#New-ADUser)
  * Create an AD user.  There are three parameter sets, RSA, NoRSA, or FromFile. RSA and NoRSA are for creating single users from the command line.
  * FromFile uses a CSV to provide data for multiple users at once.  When RSA is used an additional email is sent to the Security team to request an RSA token with the phone type.
  * With the AADSync switch, the user account will be created in the AAD synchronized OU and the user will be sent a single email explaining the AAD user registration process and a link to set the password.  A phone number is required with the AADSync option.
  * Without the AADSync switch, the user account will created in the non-AAD syncronised OU and the user will be sent an email with their account information and then a separate email with a one-time link to receive their password.
  * AD and/or AAD groups can be specified as a parameters when creating a user from the command line.  Groups should be an array of strings.
  * AD and/or AAD groups can be specified in the CSV file when creating a user from a file.  Groups should be separated by semi-colons.
* [New-OneTimeSecret](#New-OneTimeSecret)
  * Create a URL that can be used to retrieve a secret.
  * Currently the API access information is hard-coded in the function as defaults, but there is no data accessed with this identity, it only allows access to use the API.
* [New-Password](#New-Password)
  * Create a strong password from 8 to 20 characters
* [New-SA](#New-SA)
  * Create an AD service account
  * More detail to come.
* [Reset-Password](#Reset-Password)
  * Reset and AD password.  Uses the New-Password, New-OneTimeSecret, and Send-Email cmdlets.
  * More detail to come.
* [Send-Email](#Send-Email)
  * Sends an email with internal server or O365.  Provides email templates for common emails.
  * More detail to come.
<br>

## Examples

### New-AADServicePrincipal

* For more details use:
```
Get-Help New-AADServicePrincipal
```

* Syntax
```
New-AADServicePrincipal [[-Name] <string>] [-CertAuth] [-WhatIf] [-Confirm]  [<CommonParameters>]
```

* Creating a Service Principal using a 44 character password.
```
PS> New-AADServicePrincipal -Name SP-SomeApp-Environment
ClientId: 22f2c1fa-417b-40bf-9ee4-9c0172b9dc83
Password: +xHndbf2pZYPTgqlbwhd1GUvGFamNsTOJVtQatW3ny0=
```
* Creating a Service Principal using certificate authentication.
```
PS> New-AADServicePrincipal -Name 'SP-App-Env' -CertAuth
ClientId: 5b9b0e39-b209-4a85-9c33-1f84092337f0
Cert: EA7D1880733501BA11DA8DBA58578A7DBCB6DE6C
Cert PFX password: ********
Certificate exported to C:\Temp\SP-App-Env.pfx
```
##### [Return to Commands](#Commands)

### New-ADUser

* For more details use:
```
Get-Help New-ADUser
```

* Syntax
```
New-ADUser -FirstName <string> -LastName <string> -EmailAddress <string> -Description <string> [-Domain <string>] [-ADGroups <string[]>] [-AADGroups <string[]>] [-MobileNumber <string>] [-WhatIf] [-Confirm] [<CommonParameters>]

New-ADUser -FirstName <string> -LastName <string> -EmailAddress <string> -Description <string> -RSA -PhoneType {Android | iPhone} [-Domain <string>] [-ADGroups <string[]>] [-AADGroups <string[]>] [-MobileNumber <string>] [-WhatIf] [-Confirm]  [<CommonParameters>]

New-ADUser -UserFile <string> [-Domain <string>] [-WhatIf] [-Confirm]  [<CommonParameters>]
```

* Create new user from command line (With RSA request)
```
New-ADUser -FirstName 'Nancy' -LastName 'Drew' -EmailAddress 'nancy.drew@example.com' -Description 'Some Description' -PhoneType iPhone -RSA
```

* Create new user from command line (No RSA request)
```
New-ADUser -FirstName 'Nancy' -LastName 'Drew' -EmailAddress 'nancy.drew@example.com' -Description 'Some Description'
```

* Create new user from command line (Specify groups, No RSA request)
```
New-ADUser -FirstName 'Nancy' -LastName 'Drew' -EmailAddress 'nancy.drew@example.com' -Description 'Some Description' -ADGroups @('ADGroup1','ADGroup2') -AADGroups @('AADGroup1','AADGroup2')
```

* Create new user from command line (Copy groups from SourceUser)
```
New-ADUser -FirstName 'Nancy' -LastName 'Drew' -EmailAddress 'nancy.drew@example.com' -Description 'Some Description' -SourceUser 'joe.hardy@example.com'
```

* Create new users from a file
```
users.csv content:
FirstName,LastName,Description,EmailAddress,ADGroups,AADGroups,RSA,PhoneType,MobileNumber
Joe,Hardy,Test User,joe.hardy@example.com,,,,,+1 555-444-1234
Nancy,Drew,Test User,nancy.drew@example.com,,,,,+1 555-444-5678
...

New-ADUser -FromFile <path>\users.csv
```

* Create new users from a file (Specify Groups)
```
users.csv content:
FirstName,LastName,Description,EmailAddress,ADGroups,AADGroups,RSA,PhoneType,MobileNumber
Joe,Hardy,Test User,joe.hardy@example.com,ADGroup1;ADGroup2,AADGroup1;AADGroup2,,,+1 555-444-1234
Nancy,Drew,Test User,nancy.drew@example.com,ADGroup1;ADGroup2,AADGroup3;AADGroup4,,,+1 555-444-5678
...

New-ADUser -FromFile <path>\users.csv
```

* Create new users from a file (With RSA)
```
users.csv content:
FirstName,LastName,Description,EmailAddress,ADGroups,AADGroups,RSA,PhoneType,MobileNumber
Joe,Hardy,Test User,joe.hardy@example.com,,,true,iPhone,+1 555-444-1234
Nancy,Drew,Test User,nancy.drew@example.com,,,true,Android,+1 555-444-5678
...

New-ADUser -FromFile <path>\users.csv
```

##### [Return to Commands](#Commands)

### New-OneTimesSecret

* For more details use:
```
Get-Help New-OneTimeSecret
```

* Syntax
```
New-OneTimeSecret [[-Username] <string>] [[-Key] <string>] [-Secret] <string> [[-SecretTTL] <int>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

* Create a secret url.
```
$Password = New-Password
$SecretKey = New-OneTimeSecret -Secret $Password
```

* Create a secret url.
```
$Password = New-Password
$SecretKey = New-OneTimeSecret -Secret $Password -SecretTTL 24
```

##### [Return to Commands](#Commands)

## Pending Improvements

* Add function to all commands that checks the repo version of the module.
* Add #requries to all commands for any other needed modules
* Need to fix most of the tests due to name changes

##### [Return to Top](#PS-Tools)