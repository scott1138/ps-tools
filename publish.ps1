# Tag latest commit with the current version
$Version = "v$((Test-ModuleManifest ./PS-Tools/PS-Tools.psd1).version.ToString())"

git tag -a $Version -m "Release $Version"
if ($LASTEXITCODE -ne 0) {
    throw "Unable to tag commit"
}

git push origin $Version
if ($LASTEXITCODE -ne 0) {
    throw "Post tag push failed"
}


# Download updated nuget and psget versions
if ((Get-PackageProvider NuGet -ErrorAction SilentlyContinue).version -lt '2.8.5.210') {
    Install-PackageProvider NuGet -Force
}

$PowerShellGetVersion = ((Get-Module PowerShellGet -ListAvailable).Version | Sort -Descending | Select -First 1)
if ($PowerShellGetVersion -lt '2.2.1') {
    Install-Module PowerShellGet -Force -AllowClobber
    Remove-Module PowerShellGet -Force
    Import-Module PowerShellGet -Force
}

if (-not (Get-PSRepository -Name 'PS-Tools' -ErrorAction SilentlyContinue)) {
    Register-PSRepository -Name 'PS-Tools' -SourceLocation 'tbd' -PublishLocation 'tbd' -InstallationPolicy Trusted -Verbose
}

#Publish-Module -Repository 'PS-Tools' -NuGetApiKey $env:API_KEY -Path .\PS-Tools -Verbose
