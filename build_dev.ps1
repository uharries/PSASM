param(
    [string]$ModuleName = 'PASM'
)

$SourcePath = Join-Path -Path (Resolve-Path ./src) -ChildPath $ModuleName
$ModulePath = Join-Path -Path $SourcePath -ChildPath "$ModuleName.psm1"

Invoke-ScriptAnalyzer -Path $ModulePath -Settings PSScriptAnalyzerSettings.psd1 -IncludeDefaultRules -Verbose:$false

Import-Module Pester
if(!(get-module Pester).Version.Major -ge 5 ) {
    Write-Error "You need to update Pester!" -ErrorAction Stop
}
$config = New-PesterConfiguration
$config.CodeCoverage.Enabled = $false
$config.Output.Verbosity = "Normal"
$config.Output.Verbosity = "Detailed"
# $config.Output.Verbosity = "Diagnostic"
Invoke-Pester -Configuration $config

Import-Module -Name $ModulePath -Force -Verbose
Write-Host "✅ Development module loaded from: $SourcePath" -ForegroundColor Cyan

