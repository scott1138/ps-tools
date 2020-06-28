[CmdletBinding()]

param (
    [ValidateSet('None','Normal','Detailed','Diagnostic')]
    [String]
    $Output = 'Normal',

    [switch]
    $Local,

    [switch]
    $ForceBuild
)

$ErrorActionPreference = 'Stop'

# 4>$null elimates the requires errors for testing
Import-Module .\PS-Tools\PS-Tools.psd1 -Force -DisableNameChecking 4>$null

if (-not [boolean](Get-Module -Name Pester)) {
    Install-Module -Name Pester -Force -SkipPublisherCheck | Out-Null
}

$PS6PesterParams = @{
    ExcludeTag = 'PS5Only'
}

$PS5PesterParams = @{
    ExcludeTag = 'PS6Only'
}

$LinuxPesterParams = @{
    ExcludeTag = @('PS5Only','WindowsOnly')
}

if ($PSEdition -eq 'Core' -and $IsLinux) {
    $PesterParams = $LinuxPesterParams
}
elseif ($PSEdition -eq 'Core' -and $IsWindows) {
    $PesterParams = $PS6PesterParams
}
else {
    $PesterParams = $PS5PesterParams
}

if (-not $Local) {
    $PesterParams.Add('CI',$true)
}

$PesterParams.Add('Output',$Output)
$PesterParams.Add('Passthru',$true)

Write-Host "OS is Windows : $IsWindows"
Write-Host "OS is Linux   : $IsLinux"
Write-Host ""
Write-Host "PowerShell Version : $($PSVersionTable.PSVersion)"
Write-Host "PowerShell Edition : $($PSVersionTable.PSEdition)"

Write-Host "`nPester Parameters:"
Write-Output $PesterParams

# For Code Coverage
#$Functions = (Get-ChildItem -Path .\PS-Tools\ -Recurse -Include *.ps1 -Exclude *.tests.ps1,images.ps1).FullName

$TestResults = Invoke-Pester @pesterParams #-CodeCoverage $Functions

if ($TestResults.FailedCount -gt 0) {
    # Throw "Unit tests failed."
}

$Version = "v$((Test-ModuleManifest ./PS-Tools/PS-Tools.psd1).version.ToString())"

git rev-parse -q --verify refs/tags/$version
if ($LASTEXITCODE -eq 0) {
    throw "Tag $Version already exists"
}
else {
    Write-Host "Commit will be tagged $Version"
    exit 0
}
