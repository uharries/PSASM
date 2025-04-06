# --- Load Enums ---
Get-ChildItem -Path "$PSScriptRoot\Enums\*.ps1" -ErrorAction Ignore | ForEach-Object {
	. $_.FullName
}

# --- Load Classes ---
Get-ChildItem -Path "$PSScriptRoot\Classes\*.ps1" -ErrorAction Ignore | ForEach-Object {
	. $_.FullName
}

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
