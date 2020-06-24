function Handle-Error {

    [CmdletBinding()]

    param (
        [Parameter(mandatory=$true)]
        [object] $e,

        [string] $Message
    )

    $Exception     = $e.Exception.Message
    $StackTrace    = $e.ScriptStackTrace
    $ErrorPosition = $e.InvocationInfo.PositionMessage
    $FQErrorID     = $e.FullyQualifiedErrorId

    if (-not [string]::IsNullorEmpty($Message)) {
        Write-Host $Message -ForegroundColor Yellow
    }
    Write-Host $Exception -ForegroundColor Yellow
    Write-Verbose "Error Details: $ErrorPosition"
    Write-Verbose "Fully Qualified Error: $FQErrorID"
    Write-Verbose "ScriptStackTrace: $StackTrace"
    
    Throw $e
}