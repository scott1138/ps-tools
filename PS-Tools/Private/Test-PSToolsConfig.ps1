function Test-PSToolsConfig {
    [CmdletBinding()]

    param (
        [Parameter(Mandatory)]
        [string]
        $Domain

    )

    # Get the name of the calling function
    # [0] is the current function
    # [1] is the calling function
    $FunctionName = (Get-PSCallStack)[1].Command
    Write-Verbose "Testing for function $FunctionName"

    # Check to see if the PSToolsConfig variable exists
    if ($null -eq $PSToolsConfig) {
        Write-Error 'PSToolsConfig has not been set, run Set-PSToolsConfig'
        break
    }

    # use the function name to check for required values.
    if ($FunctionName -eq 'New-SA') {
        # Load Reference Settings
        $PSToolsConfigReqsPath = "$((Get-Item $PSScriptRoot).Parent)\PSToolsConfigReqs.ps1"
        Write-Verbose "Loading config from $PSToolsConfigReqsPath"
        . $PSToolsConfigReqsPath

        $MissingSetting = $false
        foreach ($Setting in $ReferenceSettings."$FunctionName") {
            Write-Verbose "Checking for $Setting"
            if ($null -eq $PSToolsConfig."$Domain".$Setting) {
                Write-Warning "Missing setting $Setting for $Domain"
                $MissingSetting = $true
            }
        }
        if ($MissingSetting) {
            Write-Error "Missing settings required for New-SA, run Set-PSToolsConfig -Domain $Domain -Function $FunctionName"
        }

    }

}