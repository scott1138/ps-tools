Function Add-DNSEntry {
  [CmdletBinding()]
  
  Param
  (
    [Parameter(Mandatory = $true, ParameterSetname = 'A')]
    [Parameter(Mandatory = $true, ParameterSetname = 'CNAME')]
    [string]
    $ZoneName,
        
    [Parameter(Mandatory = $true, ParameterSetname = 'A')]
    [Parameter(Mandatory = $true, ParameterSetname = 'CNAME')]
    [string]
    $HostName,
  
    [Parameter(Mandatory = $true, ParameterSetname = 'A')]
    [string]
    $IPAddress,

    [Parameter(Mandatory = $true, ParameterSetname = 'CNAME')]
    [string]
    $Alias,

    [Parameter(Mandatory = $true, ParameterSetname = 'A')]
    [switch]
    $A,

    [Parameter(Mandatory = $true, ParameterSetname = 'CNAME')]
    [switch]
    $CNAME
  )
  
  $ErrorActionPreference = 'Stop'
  
  Import-Module DNSServer

  # Set $Record Data to the appropriate value based on A or CNAME record creation
  # We do this to reduce the number of record comparisons
  $RecordData = if ($A) {$IPAddress} else {$Alias}

  try {
    # $Result will be null if the resource does not exists
    $Result = Get-DnsServerResourceRecord -ZoneName $ZoneName -Name $HostName -ErrorAction SilentlyContinue
    
    if (-not [boolean]$Result) {
      if ($A) {
        Add-DnsServerResourceRecordA -ZoneName $ZoneName -Name $HostName -IPv4Address $IPAddress
      }
      if ($CNAME) {
        Add-DnsServerResourceRecordCName -ZoneName $ZoneName -Name $HostName -HostNameAlias $Alias
      }
    }
    elseif ($Result.RecordData -ne $RecordData) {
      Write-Host "A record exists for $Hostname but the record data does not match." -ForegroundColor Yellow
      Write-Host "Current RecordData: $($Result.RecordData)"
      Write-Host "Desired RecordData: $RecordData"
      throw "Record exists, but data does not match!"
    }
    elseif ($Result.RecordData -eq $RecordData) {
      Write-Host "A DNS record for $HostName already exists:"
      Write-Host "RecordType: $($Result.RecordType)"
      Write-Host "RecordData: $($Result.RecordData)"
    }
  }
  catch {
    Handle-Error $_
  }
  
  <#
      .SYNOPSIS
        Add-DNSEntry
  
      .PARAMETER ZoneName
        The zone name is id the DNS zone where the record will be added.
        Examples: example.com, somedomain.com
  
      .PARAMETER HostName
        The hostname of the DNS record.
        
      .PARAMETER IPAddress

      .PARAMETER Alias

      .PARAMETER A

      .PARAMETER CNAME
  
      .EXAMPLE
  
      .LINK
      PS-Tools Project URL
          https://github.com/scott1138/ps-tools
    #>
  
} # End Function
  