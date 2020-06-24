function Get-EmailTemplate {

    <#
    .SYNOPSIS
        This function


    .EXAMPLE
        PS>

    #>

    [CmdletBinding()]

    param ()

    $ErrorActionPreference = 'Stop'

    if ($PSBoundParameters['Debug']) {
        $DebugPreference = 'Continue'
    }

    # Templates are stored in folders, images is shared and excluded from the list.
    try {
        if (-not (Test-Path -Path "$PSScriptRoot\EmailTemplates")) {
            Throw "Unable to find templates."
        }
        $Templates = Get-ChildItem -Path "$PSScriptRoot\EmailTemplates" -Exclude "Images"
    }
    catch {
        Handle-Error -e $_
    }

    foreach ($Template in $Templates) {
        $Name   = $Template.Name
        $Body   = Get-Content -path "$($Template.Fullname)\template.txt"
        $Tokens = (($Body | Select-String -AllMatches "#\w*#").Matches.Value) | Select-Object -Unique

        New-Object -TypeName PSObject -Property @{Name=$Name;Body=$Body;Tokens=$Tokens} | Select Name, Tokens, Body
    }

}

