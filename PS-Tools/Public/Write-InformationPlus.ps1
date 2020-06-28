function Write-InformationPlus {
    [CmdletBinding()]

    param (
        [Parameter(Mandatory = $true)]
        [string]
        $Message,

        [System.ConsoleColor]
        $ForegroundColor = $Host.UI.RawUI.ForegroundColor,

        [System.ConsoleColor]
        $BackgroundColor = $Host.UI.RawUI.BackgroundColor,

        [switch]
        $NoNewLine
    )

    $InformationAction = 'Continue'

    $Caller = Get-PSCallStack
    for ($i = 0; $i -lt $Caller.Count; $i++) {
        if ($Caller[$i].InvocationInfo.BoundParameters.ContainsKey('InformationAction')) {
            $InformationAction = $Caller[$i].InvocationInfo.BoundParameters['InformationAction']
            break
        }
    }

    $Msg = [System.Management.Automation.HostInformationMessage]::new()

    $Msg.Message = $Message
    $Msg.ForegroundColor = $ForegroundColor
    $Msg.BackgroundColor = $BackgroundColor
    $Msg.NoNewLine = $NoNewLine.IsPresent

    Write-Information -MessageData $Msg -InformationAction $InformationAction
}