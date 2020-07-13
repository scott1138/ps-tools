# Implement your module commands in this script.
$ModuleRoot = Split-Path -Path $MyInvocation.MyCommand.Path

$ErrorActionPreference = 'Stop'

# Load all subscripts but exclude Pester tests
$Functions = Get-ChildItem -Path $ModuleRoot -Recurse -Include *.ps1 -Exclude *.tests.ps1

foreach ($Function in $Functions) {
    try {
        . $Function.FullName
    }
    catch {
        Write-Verbose "The cmdlet $($Function.BaseName) will not be available because of the following error:" -Verbose
        Write-Verbose $_.Exception.Message -Verbose
    }
}

try {
    $PSToolsConfig = Get-Content -Path 'C:\ProgramData\PS-Tools\config.json' -ErrorAction 'Stop' | ConvertFrom-Json
    Write-Verbose "Configuration loaded from C:\ProgramDate\PS-Tools\config.json"
}
catch {
    Write-Warning "PS-Tools configuration file not found."
    Write-Warning "Run Set-PSToolsConfig to create one."
}

# Export only the functions using PowerShell standard verb-noun naming.
# Be sure to list each exported functions in the FunctionsToExport field of the module manifest file.
# This improves performance of command discovery in PowerShell.
Export-ModuleMember -Function $Functions.BaseName -Variable 'PSToolsConfig'