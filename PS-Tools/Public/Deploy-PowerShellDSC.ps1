function Deploy-PowerShellDSC {

    [CmdletBinding()]

    param (

        [Parameter(
            Mandatory = $true
        )]
        [string]
        $ConfigPath,

        [string[]]
        $AdditionalFiles

    )


    function Check-JobState {
        param
        (
            [object]$Session,
            [string]$Server,
            [string]$CurrentPhase,
            [string]$NextPhase
        )

        $Job = Get-Job -Name "${Server}_$CurrentPhase"
        if ($Job.State -eq 'Failed') {
            $Output = Receive-Job -Job $Job
            Write-InformationPlus "$Server - DSC $CurrentPhase Failed!"
            Write-InformationPlus $Output
            $Phase[$Server] = 'Failed'
            return $false
        }
        elseif ($Job.State -eq 'Running') {
            Write-InformationPlus "$Server - $CurrentPhase is still running..."
            return $false
        }
        elseif ($Job.State -eq 'Completed') {
            $Output = Receive-Job -Job $Job -AutoRemoveJob -Wait
            Write-InformationPlus "$Server - DSC $CurrentPhase completed!"
            #Write-InformationPlus $Output
            $Phase[$Server] = $NextPhase
            return $true
        }
        else {
            Write-InformationPlus "$Server - Unexpected state: $($Job.State)"
            $Phase[$Server] = 'Failed'
            return $false
        }
    }

    # Hide progress bars when receiving jobs
    $ProgressPreference = 'SilentlyContinue'
    # Stop script on any error
    $ErrorActionPreference = 'Stop'

    $Output = terraform.exe output server_names

    # Remove the unneeded characters from the Terraform output
    # Remove the opening brace
    # Remove the closing brace
    # Remove the double quotes
    # Remove white space
    # Split string by commas
    # Remove empty elements
    # Force $Server to be an array with [array]
    [array]$Servers = $Output.replace('[', '').replace(']', '').replace('"', '').replace(' ', '').split(',') | Where-Object { $_ -ne '' }


    # DNS CHECK - DNS records are required for this process to work.
    # Servers will self register, so wait for DNS records before continuing
    Write-InformationPlus "Checking for DNS records..."
    $PendingDNS = $true
    while ($PendingDNS) {
        $ServersPendingDNS = @()
        foreach ($Server in $Servers) {
            if ([bool](Resolve-DnsName -Name $Server -ErrorAction SilentlyContinue) -eq $false) {
                $ServersPendingDNS += $Server
            }
        }
        if ($ServersPendingDNS.Count -eq 0) {
            Write-InformationPlus "All DNS records found!"
            $PendingDNS = $false
        }
        else {
            Write-InformationPlus "Waiting for the following DNS records to create\propagate:`n$($ServersPendingDNS -join "`n")"
            Start-Sleep -Seconds 30
        }
    }


    # Clean up any prior failed jobs
    foreach ($Server in $Servers) {
        Get-Job -Name "$Server*" | Remove-Job -Force
    }


    # Remove any existing PSSessions and create new ones.
    foreach ($Server in $Servers) {
        Get-PSSession -Name $Server -ErrorAction SilentlyContinue | Remove-PSSession -ErrorAction SilentlyContinue
        $Session = New-PSSession -Name $Server -ComputerName $Server
    }

    # Copy files, at the moment this process is serial, but the files are small to it runs quickly.
    foreach ($Server in $Servers) {
        try {
            Write-InformationPlus "$Server - Copying DSC files..."
            $Session = Get-PSSession -Name $Server
            $Result = Invoke-Command -Session $Session -ScriptBlock { if (-not (Test-Path -Path C:\Configuration)) { New-Item -ItemType Directory -Path c:\Configuration } }
            $Result = Copy-Item -Path "$ConfigPath\*" -Destination 'C:\Configuration\' -Recurse -Force -ToSession $Session
            Write-InformationPlus "$Server - DSC files copied!"
            if ($AdditionalFiles) {
                foreach ($AdditionalFile in $AdditionalFiles) {
                    if (Test-Path $AdditionalFile -PathType Container) {
                        $Result = Copy-Item -Path "$AdditionalFile\*" -Destination 'C:\Configuration\' -Recurse -Force -ToSession $Session
                    }
                    elseif (Test-Path $AdditionalFile -PathType Leaf) {
                        $Result = Copy-Item -Path "$AdditionalFile" -Destination 'C:\Configuration\' -Force -ToSession $Session
                    }
                }
            }
        }
        catch {
            Handle-Error -e $_ -Message "Unable to copy files for $Server"
        }
    }

    # Run the DSC files
    # We need to start the commands using -InDisconnectedSession so they run as jobs
    # We also want to be able to move through the process independently for each server
    # We will use a hash table with values for each server as we bass through the check loop
    # The states will be: Unstarted, Setup, Config, Apply, Failed, Restart, DSC_Check, Finished

    # Setup Phase hashtable with Unstarted
    # Setup Logs hashtable
    $Phase = @{ }
    $Logs = @{ }
    foreach ($Server in $Servers) {
        $Phase[$Server] = 'Unstarted'
        $Logs[$Server] = "Logs for $Server"
    }

    # Setup $ActiveServers for the execution loop.
    $ActiveServers = New-Object System.Collections.ArrayList(, $Servers)

    do {
        # Commenting until some future time when I work out the issues
        # Write-InformationPlus "Remaining Servers: $($ActiveServers -join ',')"
        foreach ($Server in $ActiveServers) {
            # Get PSSesssion for this server
            $Session = Get-PSSession -Name $Server

            # If not started, call DSC setup
            if ($Phase[$Server] -eq 'Unstarted') {
                Write-InformationPlus "$Server - Starting DSC Setup..."
                $Cmd = Invoke-Command -Session $Session -ScriptBlock { C:\Configuration\dsc_setup.ps1 4>&1 } -JobName "${Server}_Setup"
                $Phase[$Server] = 'Setup'
                # Test
                #Start-Sleep -Seconds 2
            }
            # If phase is Setup, check to see if setup is finished, then create DSC Config
            if ($Phase[$Server] -eq 'Setup') {
                if (Check-JobState -Session $Session -Server $Server -CurrentPhase 'Setup' -NextPhase 'Config') {
                    Write-InformationPlus "$Server - Starting DSC Config..."
                    $Cmd = Invoke-Command -Session $Session -ScriptBlock { Invoke-Expression "C:\Configuration\dsc_config.ps1 4>&1" } -JobName "${Server}_Config"
                }
                
            }
            # If phase is Config, check to see if config is finished, then apply DSC Config
            if ($Phase[$Server] -eq 'Config') {
                if (Check-JobState -Session $Session -Server $Server -CurrentPhase 'Config' -NextPhase 'Apply') {
                    Write-InformationPlus "$Server - Starting DSC Apply..."
                    $Cmd = Invoke-Command -Session $Session -ScriptBlock { Invoke-Expression "C:\Configuration\dsc_apply.ps1 4>&1" } -JobName "${Server}_Apply"
                }
            }
            # Watch for initial DSC Apply to complete and then move to the DSC Check
            if ($Phase[$Server] -eq 'Apply') {
                Check-JobState -Session $Session -Server $Server -CurrentPhase 'Apply' -NextPhase 'DSC_Check' | Out-Null
            }
            # Check the server to see if DSC has completed applying, then move to Restart phase
            if ($Phase[$Server] -eq 'DSC_Check') {
                Write-InformationPlus "$Server - Checking DSC Configuration..."
                # Remove any existing CIM sessions for this server
                Get-CimSession -ComputerName $Server -ErrorAction SilentlyContinue | Remove-CimSession -ErrorAction SilentlyContinue
                $CimSession = New-CimSession -ComputerName $Server -ErrorAction SilentlyContinue
                if ($CimSession) {
                    $DSCStatus = Get-DSCConfigurationStatus -CimSession $CimSession
                    if ($DSCStatus.Status -eq 'Success') {
                        Write-InformationPlus "$Server - DSC Configuration Succeeded!"
                        Write-InformationPlus "$Server - $($DSCStatus.NumberOfResources) resources configured."
                        $Phase[$Server] = 'Restart'
                    }
                    elseif ($DSCStatus.Status -eq 'Failed') {
                        Write-InformationPlus "$Server - DSC Configuration Failed!"
                        Write-InformationPlus "$Server - $($DSCStatus.ResourcesInDesiredState.Count) resources succeeded."
                        Write-InformationPlus "$Server - $($DSCStatus.ResourcesNotInDesiredState.Count) resources failed."
                        $Phase[$Server] = 'Failed'
                    }
                    else {
                        Write-InformationPlus "$Server - DSC Configuration still applying..."
                    }
                }
                # Assume that if the CIMSession is null that DSC is still applying
                else {
                    Write-InformationPlus "$Server - DSC Configuration still applying..."
                }
            }
            # Restart server, then wait a few seconds before moving on to check for uptime.
            if ($Phase[$Server] -eq 'Restart') {
                Write-InformationPlus "$Server - Restarting..."
                $Result = Restart-Computer -ComputerName $Server -Force
                Start-Sleep 5
                $Phase[$Server] = 'Restarting'
            }
            if ($Phase[$Server] -eq 'Restarting') {
                if (Test-WSMan -ComputerName $Server -ErrorAction SilentlyContinue) {
                    Write-InformationPlus "$Server - Is back up!"
                    $Phase[$Server] = 'Finished'
                }
            }
        
        }

        # Assume completion and if any other state than Failed or Finished set to false
        $Completed = $true
        $Phase.GetEnumerator() | ForEach-Object {
            if ($_.value -notin @('Finished', 'Failed')) {
                $Completed = $false
            }
        }
        
        <#
        Commenting until some future time when I work out the issues
        # Clean up finished\failed servers so we don't waste time
        $Phase.GetEnumerator() | ForEach-Object {
            if ($_.Name -in $ActiveServers -and $_.Value -in @('Finished','Failed'))
            {
                Write-InformationPlus "$($_.Name) - Status is $($_.Value), removing from Servers array."
                $ActiveServers.Remove($Server)
            }
        }
        #>

        # Wait 10 seconds to give processess time to complete
        if (-not $Completed) {
            Write-InformationPlus "Waiting 10 seconds before the next update."
            Start-Sleep -Seconds 10
        }

    } until ($Completed)

    # Cleanup open sessions
    foreach ($Server in $Servers) {
        Get-PSSession -Name $Server -ErrorAction SilentlyContinue | Remove-PSSession -ErrorAction SilentlyContinue
        Get-CimSession -ComputerName $Server -ErrorAction SilentlyContinue | Remove-CimSession -ErrorAction SilentlyContinue
    }


    # Check for failed sessions and throw an error if there is an issue
    $Phase.GetEnumerator() | ForEach-Object {
        if ($_.Value -eq 'Failed') {
            throw 'One or more servers failed to configure!'
        }
    }

    <#
    .SYNOPSIS
        Deploy-PowerShellDSC is meant to streamline the PowerShell Desired State Configuration deployment process.
        The script must be run from the path of the Terrafor configuration files as it will use the output
        of 'terraform output server_names'.  It is also a requirement that the root terraform config
        output the list of created servers as server_names.

    .PARAMETER ConfigPath
        Path to the DSC configuration directory
        Relative path:
            '../Config'
        Literal Path:
            '$(System.DefaultWorkingDirectory)/<artifact name>/Config'

    .PARAMETER AdditionalFiles
        Path to any directory containing additional files to be copied
        Relative path:
            '../AdditionalFiles'
        Literal Path:
            '$(System.DefaultWorkingDirectory)/<artifact name>/AdditionalFiles'

    
    .EXAMPLE
        # Set location to the terraform configuration
        Set-Location -Path '$(System.DefaultWorkingDirectory)/<artifact name>/Terraform'
        # Make sure the PS-Tools module is imported
        Import-Module -Name PS-Tools
        # Run Deploy-PowerShellDSC passing in the configuration path
        Deploy-PowerShellDSC -ConfigPath '$(System.DefaultWorkingDirectory)/_<artifact name>/Config'


    .LINK
    PS-Tools Project URL
        https://github.com/scott1138/ps-tools
    #>

}