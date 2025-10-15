function _invokeMacro {
	[PASM()] param(
		[Parameter(Mandatory=$true, Position=0)]
		[string]$Name,

		[int]$ScopeID = 0,

		[Parameter(ValueFromRemainingArguments = $true)]
		[object[]]$MacroArgs
	)

	$v=$name.Split('.')
	# Split dotted string, but keep leading dot if present
	if ($v[0].Length -eq 0) {$v[1]='.'+$v[1];$v=$v[1..($v.count-1)]}
	$names = $v
	$nameIsQualified = $names.count -gt 1 ? $true : $false

	if ($nameIsQualified) {
		### Find start scope
		while ($true) {
			$match = $pasm.scopes.Where({$_.ParentId -eq $pasm.scopes[$scopeId].ParentId -and $_.Name -eq $names[0]})
			if ($match) { $scopeId = $match.Id; break }
			if ($scopeId -eq $pasm.scopes[$scopeId].ParentId) { break }
			$scopeId = $pasm.scopes[$scopeId].ParentId
		}
		### Find scope of Macro
		foreach ($n in $names) {
			$scopeId = $pasm.scopes.Where({$_.ParentId -eq $scopeId -and $_.Name -eq $n})?.Id ?? $scopeId
		}
		$name = $names[-1]
	} else {
		### Find scope of Macro
		while ($scopeId -ne 0 -and -not $pasm.Macros[[string]$scopeId]?[$name]) {
			$scopeId = $pasm.scopes[$scopeId].ParentId
		}
	}
	if (-not $pasm.Macros[$pasm.scopes[$scopeId].ParentId]?[$Name]) {
		$pasm.Macros | ft -auto | out-string | write-host
		throw "Macro '$Name' not found in scope $ScopeID"
	}
	$pasm.Macros[$pasm.scopes[$scopeId].ParentId][$Name].Invoke($MacroArgs)
}