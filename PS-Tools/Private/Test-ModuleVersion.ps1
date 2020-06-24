function Test-ModuleVersion {

    [CmdletBinding(SupportsShouldProcess=$True)]

    param (
    )

    $ErrorActionPreference = 'Stop'

    if ($PSBoundParameters['Debug']) {
        $DebugPreference = 'Continue'
    }

    try {
        $GalleryVersion = (Find-Module PS-Tools).Version
        $LocalVersion   = (Get-Module PS-Tools).Version
        if ($GalleryVersion -gt $LocalVersion) {
            Write-Warning "The PS-Tools module is out of date!"
            Write-Warning "Local version  : $LocalVersion"
            Write-Warning "Gallery version: $GalleryVersion"
            Write-Warning "Press Ctrl-C to exit or enter continue."
            $ForegroundColor = $Host.UI.RawUI.ForegroundColor
            $Host.UI.RawUI.ForegroundColor = $Host.UI.RawUI.BackgroundColor
            $null = Read-Host
            $Host.UI.RawUI.ForegroundColor = $ForegroundColor
        }
        else {
            Write-Verbose "The PS-Tools module is current - $LocalVersion"
        }
    }
    catch {
        $Exception = $_.Exception.Message
        Write-Warning "Unable to check for PS-Tools updates.  The following error occurred`n`n$Exception"
    }

    <#
    .SYNOPSIS

    .PARAMETER

    .EXAMPLE
        PS> 

    .LINK
        PS-Tools Project URL
        https://github.com/scott1138/ps-tools
    #>
}