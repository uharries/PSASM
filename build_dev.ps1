# Using module PSScriptAnalyzer

param(
    [string]$ModuleName = 'PASM',
    [switch]$debug
)
write-host "DEBUG: $debug"
$SourcePath = Join-Path -Path (Resolve-Path ./src) -ChildPath $ModuleName
$ModulePath = (Resolve-Path(Join-Path -Path $SourcePath -ChildPath "$ModuleName.psm1")).Path

Install-PSResource -Name PSScriptAnalyzer
Import-Module PSScriptAnalyzer
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
if (-not $debug) {
    Invoke-Pester -Configuration $config
}

if (get-module $ModuleName) {
    $macros = Get-PASMFunction -ListMacros
    if ($macros) {
        $macros | %{if (Test-Path "Function:\$_") { Remove-Item "Function:\$_" -Force }}
    }
}
Remove-Module $ModuleName -Force -ErrorAction SilentlyContinue
Import-Module $ModulePath -Force -Verbose

Write-Host "✅ Development module loaded from: $SourcePath" -ForegroundColor Cyan

