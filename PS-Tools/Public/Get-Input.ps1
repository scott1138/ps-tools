function Get-Input {

    [CmdletBinding()]

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
        $UserInput = (Read-Host -Prompt "$Prompt [$Default]").Trim()
        
        if (-not [string]::IsNullOrEmpty($Default) -and [string]::IsNullOrEmpty($UserInput)) {
            return $Default
        }
        elseif ([boolean]$ValidResponses) {
            if ($MultipleChoice) {
                # We are looking for responses in the $UserInput that are not in $ValidResponses
                # This would result in a '=>' side indicator.  If one is found the conditional is $false
                $UserInput = $UserInput.Split(',')
                if ((Compare-Object -ReferenceObject $ValidResponses -DifferenceObject $UserInput).SideIndicator -notcontains '=>') {
                    return $UserInput
                }
                else {
                    Write-InformationPlus "`n$UserInput was not a valid response, please try again.`n" -ForeGroundColor Yellow
                    Write-InformationPlus "Valid Choices: $($ValidResponses -join ',')`n" -ForeGroundColor Yellow    
                }
            }
            elseif ($UserInput -in $ValidResponses) {
                return $UserInput
            }
            else {
                Write-InformationPlus "`n$UserInput was not a valid response, please try again.`n" -ForeGroundColor Yellow
                Write-InformationPlus "Valid Responses: $($ValidResponses -join ',')`n" -ForeGroundColor Yellow
            }
        }
        elseif (-not [string]::IsNullOrEmpty($Match)) {
            if ($UserInput -match $Match) {
                return $UserInput
            }
            else {
                Write-InformationPlus "`n$UserInput was not a valid response, please try again.`n" -ForeGroundColor Yellow
                Write-InformationPlus "Valid input should match the pattern: $Match`n" -ForeGroundColor Yellow
                if (-not [string]::IsNullOrEmpty($MatchHint)) {
                    Write-InformationPlus "$MatchHint`n" -ForeGroundColor Yellow
                }
            }
        }
        elseif ($Required) {
            if ([string]::IsNullOrEmpty($UserInput)) {
                Write-InformationPlus "`nThis field requires a value, please enter the required data.`n" -ForeGroundColor Yellow
            }
            else {
                return $UserInput
            }
        }
        else {
            return $UserInput
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