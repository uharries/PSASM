# --- Load Globals ---
Get-ChildItem -Path "$PSScriptRoot\Globals\*.ps1" -ErrorAction Ignore | ForEach-Object {
	. $_.FullName
}

# --- Load Enums ---
Get-ChildItem -Path "$PSScriptRoot\Enums\*.ps1" -ErrorAction Ignore | ForEach-Object {
	. $_.FullName
}

# --- Load Classes ---
# Get-ChildItem -Path "$PSScriptRoot\Classes\*.ps1" -ErrorAction Ignore | ForEach-Object {
# 	. $_.FullName
# }
. "$PSScriptRoot\Classes\Token.ps1"
. "$PSScriptRoot\Classes\Tokenizer.ps1"
. "$PSScriptRoot\Classes\Parser.ps1"
. "$PSScriptRoot\Classes\PASMAttribute.ps1"
. "$PSScriptRoot\Classes\AssemblerInformation.ps1"
. "$PSScriptRoot\Classes\AssemblyLine.ps1"
. "$PSScriptRoot\Classes\MOS6502.ps1"
. "$PSScriptRoot\Classes\PASM.ps1"


# --- Load Private Functions ---
Get-ChildItem -Path "$PSScriptRoot\Functions\Private\*.ps1" -ErrorAction Ignore | ForEach-Object {
	. $_.FullName
}

# --- Load Public Functions ---
$PublicFunctions = Get-ChildItem -Path "$PSScriptRoot\Functions\Public\*.ps1" -ErrorAction Ignore

foreach ($FunctionFile in $PublicFunctions) {
	. $FunctionFile.FullName
}

# --- Export Only Public Functions ---
Export-ModuleMember -Function $PublicFunctions.BaseName
