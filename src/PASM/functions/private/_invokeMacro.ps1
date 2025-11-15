function _invokeMacro {
	[PASM()] param(
		[Parameter(Mandatory=$true, Position=0)]
		[string]$Name,

		[int]$ScopeID = 0,

		[Parameter(ValueFromRemainingArguments = $true)]
		[object[]]$MacroArgs
	)

	$r = $pasm.symbolManager.ResolveNameAndScope($Name, $ScopeID)
	if (-not $r.Resolved) {
		throw "Macro '$Name' not found in scope $ScopeID"
	}

	# $MacroArgs.GetType() | ft -auto | out-string | write-host
	# $MacroArgs | ft -auto | out-string | write-host
	# Arguments passed to Invoke must be forcibly passed as a single element array, eventhough it's already an object[], otherwise PS will unwrap the individual arguments
	if (-not $pasm.Macros[$r.ScopeId]?[$r.Name]) {
		throw "Symbol '$Name' in scope '$($r.ScopeId):$($r.ScopeName)' is not a macro or not yet instantiated"
	}
	$pasm.Macros[$r.ScopeId][$r.Name].InvokeReturnAsIs( (,$MacroArgs))
}