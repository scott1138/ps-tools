function Get-Input {

    [CmdletBinding(SupportsShouldProcess=$True)]

    param (
        [Parameter(Mandatory=$True)]
        [string] $Prompt,

        [string] $Default,

        [string[]] $ValidResponses,

        [switch] $MultipleChoice,

        [string] $Match,

        [string] $MatchHint,

        [switch] $Required
    )

    $ErrorActionPreference = 'Stop'

    if ($PSBoundParameters['Debug']) {
        $DebugPreference = 'Continue'
    }

    $Complete = $false

    Do {
        # Trim removes whitespace from the beginning and end of responses
        # This makes sure we don't get accidentally blank reponses
        # or invalidate responses because of accidental spacebar press
        if ($MultipleChoice) {
            Write-InformationPlus 'The following question allows for multiple responses.'
            Write-InformationPlus 'Please separate those responses with a comma.'
        }
        $Input = (Read-Host -Prompt "$Prompt [$Default]").Trim()
        
        if (-not [string]::IsNullOrEmpty($Default) -and [string]::IsNullOrEmpty($Input)) {
            return $Default
        }
        elseif ([boolean]$ValidResponses) {
            if ($MultipleChoice) {
                # We are looking for responses in the $Input that are not in $ValidResponses
                # This would result in a '=>' side indicator.  If one is found the conditional is $false
                $Input = $Input.Split(',')
                if ((Compare-Object -ReferenceObject $ValidResponses -DifferenceObject $Input).SideIndicator -notcontains '=>') {
                    return $Input
                }
                else {
                    Write-InformationPlus "`n$Input was not a valid response, please try again.`n" -ForeGroundColor Yellow
                    Write-InformationPlus "Valid Choices: $($ValidResponses -join ',')`n" -ForeGroundColor Yellow    
                }
            }
            elseif ($Input -in $ValidResponses) {
                return $Input
            }
            else {
                Write-InformationPlus "`n$Input was not a valid response, please try again.`n" -ForeGroundColor Yellow
                Write-InformationPlus "Valid Responses: $($ValidResponses -join ',')`n" -ForeGroundColor Yellow
            }
        }
        elseif (-not [string]::IsNullOrEmpty($Match)) {
            if ($Input -match $Match) {
                return $Input
            }
            else {
                Write-InformationPlus "`n$Input was not a valid response, please try again.`n" -ForeGroundColor Yellow
                Write-InformationPlus "Valid input should match the pattern: $Match`n" -ForeGroundColor Yellow
                if (-not [string]::IsNullOrEmpty($MatchHint)) {
                    Write-InformationPlus "$MatchHint`n" -ForeGroundColor Yellow
                }
            }
        }
        elseif ($Required) {
            if ([string]::IsNullOrEmpty($Input)) {
                Write-InformationPlus "`nThis field requires a value, please enter the required data.`n" -ForeGroundColor Yellow
            }
            else {
                return $Input
            }
        }
        else {
            return $Input
        }
        
    }
    Until ($Complete)

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