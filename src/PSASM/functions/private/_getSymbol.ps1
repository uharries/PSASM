function _getSymbol {
	[PSASM(noSymbolSupport)] param (
		[Parameter(Mandatory)]
		[string]$name,
		[int]$scopeId = 0,
		[string]$InvocationFile,
		[int]$InvocationLine,
		[int]$InvocationColumn
	)
	# Write-Host "_getSymbol('$name', $scopeId, $callerLine, $callerColumn)" -ForegroundColor Magenta
	# Write-Host "  _getSymbol: return $($psasm.symbolManager.GetSymbol($name, $scopeId, $callerLine, $callerColumn, $MyInvocation).Value)" -ForegroundColor Magenta
	# $val = $sym.Values.Count -gt 0 ? $sym.Values[$sym.Values.Count - 1] : 0
	$symVal = [object]$psasm.symbolManager.GetSymbol($name, $scopeId, $InvocationFile, $InvocationLine, $InvocationColumn, $MyInvocation).Value

	# this effectively makes the [Undefined] checks in the directives like .byte and .word never trigger
	# not really sure what troubles will come from this, but the alternatives appear a lot more complicated...
	# a .net class defining overloads for all possible operations or a wrapper for expressions, i then need to inject in the semantic parser.
	# let's see where this takes me for now...
	return $symVal -is [Undefined] ? $symVal.Value : $symVal
}
