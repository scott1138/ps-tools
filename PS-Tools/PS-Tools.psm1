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


# Export only the functions using PowerShell standard verb-noun naming.
# Be sure to list each exported functions in the FunctionsToExport field of the module manifest file.
# This improves performance of command discovery in PowerShell.
Export-ModuleMember -Function *-*

