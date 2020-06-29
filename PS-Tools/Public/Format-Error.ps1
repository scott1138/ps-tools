function Format-Error {

    [CmdletBinding()]

    param (
        [Parameter(mandatory = $true)]
        [object] $e,

        [string] $Message
    )

    $Exception = $e.Exception.Message
    $ScriptStackTrace = $e.ScriptStackTrace
    $ErrorPosition = $e.InvocationInfo.PositionMessage
    $FQErrorID = $e.FullyQualifiedErrorId

    if (-not [string]::IsNullorEmpty($Message)) {
        Write-InformationPlus $Message -ForegroundColor Yellow
    }
    Write-InformationPlus $Exception -ForegroundColor Yellow
    Write-Verbose "Error Details: $ErrorPosition"
    Write-Verbose "Fully Qualified Error: $FQErrorID"
    Write-Verbose "ScriptStackTrace: $ScriptStackTrace"
    
    Throw $e
}