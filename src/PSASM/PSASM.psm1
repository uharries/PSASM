# --- Load Globals ---
Get-ChildItem -Path "$PSScriptRoot\Globals\*.ps1" -ErrorAction Ignore | ForEach-Object {
	. $_.FullName
}

$versionInfoPath = Join-Path $PSScriptRoot 'globals/VersionInfo.ps1'
if (-not (Test-Path $versionInfoPath)) {
    $script:ModuleVersion   = 'unknown'
    $script:ModuleBuildDate = 'not built'
}

# --- Load Enums ---
Get-ChildItem -Path "$PSScriptRoot\Enums\*.ps1" -ErrorAction Ignore | ForEach-Object {
	. $_.FullName
}

# --- Load Classes ---
# Get-ChildItem -Path "$PSScriptRoot\Classes\*.ps1" -ErrorAction Ignore | ForEach-Object {
# 	. $_.FullName
# }
. "$PSScriptRoot\Classes\MultiLevelCounter.ps1"
. "$PSScriptRoot\Classes\InputFileContext.ps1"
. "$PSScriptRoot\Classes\InputFileStack.ps1"
. "$PSScriptRoot\Classes\Token.ps1"
. "$PSScriptRoot\Classes\Tokenizer.ps1"
. "$PSScriptRoot\Classes\Scope.ps1"
. "$PSScriptRoot\Classes\ScopeManager.ps1"
. "$PSScriptRoot\Classes\SymbolEntry.ps1"
. "$PSScriptRoot\Classes\SymbolManager.ps1"
. "$PSScriptRoot\Classes\SemanticParser.ps1"
. "$PSScriptRoot\Classes\PSASMAttribute.ps1"
. "$PSScriptRoot\Classes\AssemblyLine.ps1"
. "$PSScriptRoot\Classes\MOS6502.ps1"
. "$PSScriptRoot\Classes\AssemblyResult.ps1"
. "$PSScriptRoot\Classes\SegmentManager.ps1"
. "$PSScriptRoot\Classes\Assembler.ps1"

# --- Load Private Functions ---
Get-ChildItem -Path "$PSScriptRoot\Functions\Private\*.ps1" -ErrorAction Ignore | ForEach-Object {
	. $_.FullName
}

# --- Load Public Functions ---
$PublicFunctions = Get-ChildItem -Path "$PSScriptRoot\Functions\Public\*.ps1" -ErrorAction Ignore

foreach ($FunctionFile in $PublicFunctions) {
	. $FunctionFile.FullName
}

Set-Alias -Name psasm -Value Invoke-Assembler -Description "Invoke the PSASM assembler"
