# Using module PSScriptAnalyzer

param(
	[string]$ModuleName = 'PASM',
	[switch]$debug
)
write-host "DEBUG: $debug"
$SourcePath = Join-Path -Path (Resolve-Path ./src) -ChildPath $ModuleName
$ModulePath = (Resolve-Path(Join-Path -Path $SourcePath -ChildPath "$ModuleName.psm1")).Path

# Define modules and minimum required versions
$Modules = @{
	"PSScriptAnalyzer" = "1.24.0"
	"Pester"           = "5.6.1"
}

foreach ($m in $Modules.Keys) {
	$minVersion = $Modules[$m]
	$installed = Get-PSResource -Name $m -Version "[$($Modules[$m]), ]" -ErrorAction SilentlyContinue | Sort-Object Version -Descending | Select-Object -First 1

	if (-not $installed) {
		Write-Host "Installing/updating module '$m' to at least version $minVersion..."
		Install-PSResource -Name $m -Version "[$($Modules[$m]), ]" -Scope CurrentUser -TrustRepository
	}

	$toImport = Get-Module -ListAvailable -Name $m | Where-Object { [Version]$Modules[$m] -ge $minVersion } | Sort-Object Version -Descending | Select-Object -First 1

	if ($toImport) {
		Write-Host "Importing module '$m' version $($toImport.Version)..."
		Import-Module $toImport -Force
	}
}

Invoke-ScriptAnalyzer -Path $ModulePath -Settings PSScriptAnalyzerSettings.psd1 -IncludeDefaultRules -Verbose:$false

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

# Have to do this after building, as Get-PASMFunction needs the module loaded
# so build twice to update the list of directives in common.ps1
$commonPath = (Resolve-Path(Join-Path -Path $SourcePath -ChildPath "globals/common.ps1")).Path
$directives = "`$PASMFunctions = (`"$((Get-PASMFunction).Name -join '", "')`")"
(Get-Content $commonPath) | ForEach-Object { if ($_ -match '^\$PASMFunctions\s*=') { $directives } else { $_ } } | Set-Content $commonPath -Force


Write-Host "✅ Development module loaded from: $SourcePath" -ForegroundColor Cyan

