function Get-RandomServerList {

  [CmdletBinding()]

  param (
    [Parameter(Mandatory=$True)]
    [string[]] $BaseServers,

    [Parameter(Mandatory=$True)]
    [int] $Count
  )

  $ErrorActionPreference = 'Stop'

  if ($PSBoundParameters['Debug']) {
      $DebugPreference = 'Continue'
  }

  Write-Verbose "BaseServer contains $($BaseServers.Count) servers"

  $ExecStart = Get-Date

  $Servers = @()
  $DupeCount = 0
  $DeadCount = 0
  
  do {
    $Index = Get-Random -Maximum ($BaseServers.Count-1)
    if (Test-Connection -ComputerName $BaseServers[$index] -Quiet -Count 1 -ErrorAction SilentlyContinue) {
      if (-not $Servers.Contains($BaseServers[$Index])) {
        $Servers += $BaseServers[$Index]
      }
      else {
        $DupeCount += 1
      }
    }
    else {
      $DeadCount += 1
    }
    Write-Progress -Activity 'Getting random set of servers' -Status "$($Count-$Servers.count) to go!"
  } Until ($Servers.Count -ge $Count)
  
  $ExecEnd = Get-Date
  $ExecTime = (New-TimeSpan -Start $ExecStart -End $ExecEnd).TotalSeconds
  
  Write-Verbose "Execution time: $ExecTime seconds"
  Write-Verbose "Duplicate attempts  : $DupeCount"
  Write-Verbose "Unreachable systems : $DeadCount"
  
  Write-Output $Servers
}