function Set-ResourceGroupTags {
    [CmdletBinding()]

    param (
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo]$DataPath,

        [string[]]$TagsToRemove
    )

    $Global:ErrorActionPreference = 'Stop'

    $Resources = Import-Csv -Path $DataPath

    # Make sure the required fields are present
    $ReqProperties = @('ID','NAME','Component','Environment')
    $Properties = $Resources[0].psobject.Properties.Name
    $PropertyCheck = (Compare-Object -ReferenceObject $ReqProperties -DifferenceObject $Properties -IncludeEqual).Count
    Write-Verbose "CSV Properties -"
    Write-Verbose "Expected: $ReqProperties"
    Write-Verbose "Found   : $Properties"
    Write-Verbose "Check   : $PropertyCheck"
    if ($PropertyCheck -ne 4) {
        Write-Error "Invalid Source Data.  Please make sure that the Id, Name, Component, and Environment properties are set."
    }

    # Create logging folder in current path
    $LogPath = '.\Logs'
    if (-not (Test-Path $LogPath)) {
        New-Item -ItemType Directory -Path $LogPath
    }
    Write-Verbose "LogPath : $LogPath"

    $Subscriptions = @(Get-AzSubscription)

    foreach ($Subscription in $Subscriptions) {

        $NotExists = [System.Collections.Concurrent.ConcurrentBag[object]]::new()
        $Succeeded = [System.Collections.Concurrent.ConcurrentBag[object]]::new()
        $Failed = [System.Collections.Concurrent.ConcurrentBag[object]]::new()

        $ThreadSafeCounter = [System.Collections.Concurrent.ConcurrentBag[object]]::new()

        $SubNum = $Subscriptions.IndexOf($Subscription) + 1
        $SubCount = $Subscriptions.Count

        Write-Host "Processing subscription $($Subscription.Name) - ($SubNum of $SubCount)"

        Select-AzSubscription $Subscription | Out-Null

        $Context = Get-AzContext

        $CurrResources = $Resources | Where-Object {$_.id -match $Context.Subscription.id}

        $TotalResources = $CurrResources.Count

        $CurrResources | Foreach-Object -Throttle 5 -Parallel {

            $Resource = $_

            $LocalFailed = $Using:Failed
            $LocalSucceeded = $Using:Succeeded
            $LocalNotExists = $Using:NotExists

            $Counter = $Using:ThreadSafeCounter
            $Counter.Add($Resource)
            $Count = $Counter.Count

            Write-Host "`rProcessed $Count out of $Using:TotalResources" -NoNewLine

            # Reset variable
            $AzResourceGroup = $null

            # Fixes conflict with Az module and Azure token
            Start-Sleep -Milliseconds (Get-Random -Maximum 3000)

            try {
                $AzResourceGroup = Get-AzResourceGroup -ResourceId $Resource.id -ErrorAction Stop
            }
            catch {
                $ErrObject = New-Object -TypeName psobject -Property @{Id = $Resource.id;Component = $Resource.Component;Environment = $Resource.Environment;Error = ($_.Exception.Message -split "`n")[0]}
                $LocalFailed.Add($ErrObject)
            }

            if ($null -eq $AzResourceGroup) {
                # resource may have been deleted, continue loop
                $LocalNotExists.Add($Resource)
            }
            else {
                try {

                    if (!($AzResourceGroup.Tags -as [System.Boolean])) {
                        $AzResourceGroup.Tags = @{}
                    }
                    if ($AzResourceGroup.Tags.ContainsKey('Component')) {
                        $AzResourceGroup.Tags['Component'] = $Resource.Component
                    }
                    else {
                        $AzResourceGroup.Tags.Add('Component',$Resource.Component)
                    }

                    if ($AzResourceGroup.Tags.ContainsKey('Environment')) {
                        $AzResourceGroup.Tags['Environment'] = $Resource.Environment
                    }
                    else {
                        $AzResourceGroup.Tags.Add('Environment',$Resource.Environment)
                    }
                    
                    foreach ($Tag in $TagsToRemove) {
                        if ($AzResourceGroup.tags.ContainsKey($Tag)) {
                            $AzResourceGroup.Tags.Remove($Tag)
                        }
                    }

                    Set-AzResourceGroup -ResourceId $AzResourceGroup.ResourceId -Tag $AzResourceGroup.Tags -ErrorAction Stop | Out-Null
                    
                    $LocalSucceeded.Add($Resource)
                }
                catch {
                    $ErrObject = New-Object -TypeName psobject -Property @{id = $Resource.id;error = ($_.Exception.Message -split "`n")[0]}
                    $LocalFailed.Add($ErrObject)
                }

            }
            
        } # End Resource Loop

        Write-Host "`n"

        $TimeStamp = Get-TimeStamp 

        $Succeeded | Export-Csv -NoTypeInformation -Path "$LogPath\$($Subscription.name)_Succeeded_$Timestamp.csv"
        $Failed | Export-Csv -NoTypeInformation -Path "$LogPath\$($Subscription.name)_Failed_$Timestamp.csv"
        $NotExists | Export-Csv -NoTypeInformation -Path "$LogPath\$($Subscription.name)_Notexists_$Timestamp.csv"

    } # End Subscriptions Loop

}