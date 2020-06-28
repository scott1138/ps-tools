function Refresh-Module {

    [CmdletBinding(SupportsShouldProcess=$True)]

    Param ()
    
    DynamicParam {
 
        # Set the dynamic parameters' name
        $ParameterName = 'ModuleName'

        # Create the dictionary
        $RuntimeParameterDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary

        # Create the collection of attributes
        $AttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]

        # Create and set the parameters' attributes
        $ParameterAttribute = New-Object System.Management.Automation.ParameterAttribute
        $ParameterAttribute.Mandatory = $true
        $ParameterAttribute.Position = 1

        # Add the attributes to the attributes collection
        $AttributeCollection.Add($ParameterAttribute)

        # Generate and set the ValidateSet
        $arrSet = (Get-Module -ListAvailable).Name
        $ValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($arrSet)

        # Add the ValidateSet to the attributes collection
        $AttributeCollection.Add($ValidateSetAttribute)

        # Create and return the dynamic parameter
        $RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($ParameterName, [string], $AttributeCollection)
        $RuntimeParameterDictionary.Add($ParameterName, $RuntimeParameter)
        return $RuntimeParameterDictionary
    }

    begin {
        $ErrorActionPreference = 'Stop'

        if ($PSBoundParameters['Debug']) {
            $DebugPreference = 'Continue'
        }

        $ModuleName = $PSBoundParameters['ModuleName']
    }

    process {

        try {
            $ErrorActionPreference  = 'SilentlyContinue'
            $Version = (Get-Module PS-Tools -ListAvailable | Sort Version -Descending | Select -First 1).Version
            Write-InformationPlus "$ModuleName - currently at $Version"
            Write-InformationPlus "Updating..."

            Remove-Module $ModuleName -Force
            Update-Module $ModuleName -Force
            Import-Module $ModuleName -Force

            $Version = (Get-Module $ModuleName).Version.ToString()
            Write-InformationPlus "$ModuleName - updated to $Version"

            $ModuleRoot = Split-Path  -Path (Get-Module $ModuleName).ModuleBase -Parent
            $OldVersions = Get-ChildItem -Path $ModuleRoot -Exclude $Version
            $OldVersions | Remove-Item -Recurse -Force
            Write-InformationPlus "Removed versions: $($OldVersions.Name -join ', ')"
        }
        catch {
            Write-InformationPlus "Module Refresh Failed!" -ForegroundColor Yellow
            Write-InformationPlus $_.Exception.Message -ForegroundColor Yellow
        }

    }

    <#
    .SYNOPSIS
        Removes, Updates, and Imports a module to make sure the latest version is running.

    .PARAMETER ModuleName
        Name of the module to update.

    .EXAMPLE
        PS> 

    .LINK
        PS-Tools Project URL
        https://github.com/scott1138/ps-tools
    #>
}