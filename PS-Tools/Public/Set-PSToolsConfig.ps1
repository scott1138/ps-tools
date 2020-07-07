function Set-PSToolsConfig {
    [CmdletBinding(
        SupportsShouldProcess = $true,
        DefaultParameterSetName = 'Manual'
    )]

    param (
        [string]
        $Domain = ((Get-ADDomain).DNSRoot),

        [Parameter(
            Mandatory = $true,
            ParameterSetName = 'Manual'
        )]
        [ValidateSet('New-SA')]
        [string]
        $FunctionName,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = 'Auto'
        )]
        [hashtable]
        $ConfigValues
    )

    # Reload Configuration from File to make sure it is in the correct form
    try {
        $Global:PSToolsConfig = Get-Content -Path 'C:\ProgramData\PS-Tools\config.json' -ErrorAction 'Stop' | ConvertFrom-Json -AsHashtable
        Write-Verbose "Current Configuration loaded."
    }
    catch {
        $Global:PSToolsConfig = @{}
        Write-Verbose "No Configuration Present."
    }

    # Check for Domain
    if ($Global:PSToolsConfig."$Domain") {
        Write-Verbose "Domain exists in configuration."
    }
    else {
        $Global:PSToolsConfig.Add($Domain,@{})
        Write-Verbose "Domain added to configuration."
    }

    # Shortcut to domain config
    $Config = $Global:PSToolsConfig."$Domain"

    # Load reference settings object
    $PSToolsConfigReqsPath = "$((Get-Item $PSScriptRoot).Parent)\PSToolsConfigReqs.ps1"
    Write-Verbose "Loading config from $PSToolsConfigReqsPath"
    . $PSToolsConfigReqsPath

    # Filter settings to ask for based on function name
    if ($PSBoundParameters.Keys -contains 'FunctionName') {
        Write-Verbose "Processing settings for function $FunctionName"
        $Settings = $ReferenceSettings."$FunctionName"
    }
    else {
        $Settings = $ReferenceSettings.GetEnumerator() | ForEach-Object { $_.Value }
    }

    # Get valid organizational units
    $OUs = (Get-ADOrganizationalUnit -Filter * -Credential $cred -Server dalprddom01.freemanco.com).DistinguishedName
    Write-Verbose "$($OUs.Count) Organizational Units retrieved."

    # Get valid group names
    $Groups = (Get-ADGroup -Filter * -Credential $cred -Server dalprddom01.freemanco.com).Name
    Write-Verbose "$($Groups.Count) AD Groups retrieved."

    # Can we make suggestions on incorrect OU or Group Names?
    if (Get-InstalledModule -Name Communary.PASM) {
        $Fuzzy = $true
    }
    else {
        $Fuzzy = $false
        Write-InformationPlus -Message 'Install module Communary.PASM to enable fuzzy match checking on your AD entries.'
    }

    # Ask for a value for each setting
    foreach ($Setting in $Settings) {
        $Validated = $false
        $Default = $Config."$Setting"
        do {
            if ($Setting -match "^.*OU$") {
                $ValidationType = 'Organizational Unit'
                $ValidationSet = $OUs
            }
            elseif ($Setting -match "^.*Group$") {
                $ValidationType = 'AD Group'
                $ValidationSet = $Groups
            }

            $Value = Get-Input -Prompt "$Setting" -Default $Default
            
            if ($ValidationSet -notcontains $Value) {
                Write-InformationPlus -Message "$Value is not a valid $ValidationType." -ForegroundColor Yellow
                if ($Fuzzy) {
                    $FuzzyMatch = ($ValidationSet | Select-FuzzyString -Search $Value | Sort-Object -Property Score -Descending | Select-Object -First 1).Result
                    Write-InformationPlus -Message "Did you mean:`n$FuzzyMatch"
                    $Default = $FuzzyMatch
                }
            }
            else {
                $Validated = $true
            }
        } until ($Validated)

        if ($Config.Keys -notcontains $Setting) {
            $Config.Add($Setting, $Value)
        }
        else {
            $Config."$Setting" = $Value
        }

    } # End add settings loop

    if (-not (Test-Path -Path 'C:\ProgramData\PS-Tools\')) {
        New-Item -ItemType Directory -Path 'C:\ProgramData\PS-Tools\'
    }

    $Global:PSToolsConfig | ConvertTo-Json | Set-Content -Path 'C:\ProgramData\PS-Tools\config.json'
}