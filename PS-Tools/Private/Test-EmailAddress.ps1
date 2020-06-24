function Test-EmailAddress {

    [CmdletBinding()]

    param (
        [string] $EmailAddress
    )

    Write-Verbose "Testing Email Address: $EmailAddress"

    try {
        [mailaddress]$EmailAddress | Out-Null
        return $true
    }
    catch {
        return $false
    }

}