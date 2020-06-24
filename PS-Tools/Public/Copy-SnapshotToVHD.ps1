function Copy-SnapshotToVHD {
    [CmdletBinding()]
    param (
        
        [Parameter(Mandatory = $true)]
        [string]
        $SnapshotName,

        [Parameter(Mandatory = $true)]
        [string]
        $SnapshotResourceGroupName,

        [Parameter(Mandatory = $true)]
        [string]
        $StorageAccountName,

        [Parameter(Mandatory = $true)]
        [string]
        $StorageAccountKey,

        [Parameter(Mandatory = $true)]
        [string]
        $ContainerName,

        [Parameter(Mandatory = $true)]
        [string]
        $VHDName
        
    )
    
    begin {
        $ErrorActionPreference = 'Stop'
    }
    
    process {
        # Verify Snapshot Exists
        try {
            Get-AzSnapshot -ResourceGroupName $SnapshotResourceGroupName -SnapshotName $SnapshotName | Out-Null
        }
        catch {
            $ErrorMsg =
            "Snapshot not found! Please verify the Resource Group and Snapshot names.
             Resource Group Name: $SnapshotResourceGroupName
             Snapshot Name      : $SnapshotName"
            Write-Error $ErrorMsg
        }

        # Verify Storage Account Exists
        try {
            if (-not (Get-AzStorageAccount | Where-Object {$_.StorageAccountName -eq $StorageAccountName})) {
                throw
            }
        }
        catch {
            $ErrorMsg =
            "Storage Account not found! Please verify the storage account name.
             Storage Account Name: $StorageAccountName"
            Write-Error $ErrorMsg
        }

        # Create Snapshot 
        try {
            Write-Verbose 'Beginning Snapshot SAS creation.'
            $SAS = Grant-AzSnapshotAccess -ResourceGroupName $SnapshotResourceGroupName -SnapshotName $SnapshotName -DurationInSecond 86400 -Access Read
            Write-Verbose 'Snapshot SAS created successfully.'
        }
        catch {
            Write-Error "Unable to obtain SAS for the snapshot, check your access permissions.`n`n$_"
        }

        # Set and confirm Azure Storage Context
        try {
            $Context = New-AzStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey
            Get-AzStorageContainer -Context $Context | Out-Null
            Write-Verbose 'Storage context set successfully.'
        }
        catch {
            Write-Error "Unable to set Azure Storage Context.`n`n$_"
        }

        # Check for the container and create if it does not exist
        if (-not (Get-AzStorageContainer -Context $Context -Container $ContainerName -ErrorAction SilentlyContinue)) {
            try {
                Write-Verbose $ContainerName
                New-AzStorageContainer -Context $Context -Container $ContainerName | Out-Null
                Write-Verbose "Cointainer $ContainerName created successfully."
            }
            catch {
                Write-Error "Unable to create the container.`n`n$_"
            }
        }

        try {
            Start-AzStorageBlobCopy -AbsoluteUri $SAS.AccessSAS -DestContainer $ContainerName -DestContext $Context -DestBlob $VHDName
        }
        catch {
            Write-Error "Unable to start the copy.`n`n$_"
        }

    }
    
    end {
        
    }
}