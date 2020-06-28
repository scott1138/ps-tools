Describe 'Module Manifest Tests' {
    
    It 'Passes Test-ModuleManifest' {
        $ModuleManifestName = 'PS-Tools.psd1'
        $ModuleManifestPath = "$PSScriptRoot\..\$ModuleManifestName"
        Write-Verbose "PS-Tools Manifest Test"
        Write-Verbose "ModuleManifestPath: $ModuleManifestPath"
        Test-ModuleManifest -Path $ModuleManifestPath | Should -Not -BeNullOrEmpty
        $? | Should -Be $true
    }
    
}

