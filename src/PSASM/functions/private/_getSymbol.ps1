function _getSymbol {
	[PSASM(noSymbolSupport)] param (
		[Parameter(Mandatory)]
		[string]$name,
		[int]$scopeId = 0,
		[int]$callerLine,
		[int]$callerColumn
	)
	# Write-Host "_getSymbol('$name', $scopeId, $callerLine, $callerColumn)" -ForegroundColor Magenta
	# Write-Host "  _getSymbol: return $($psasm.symbolManager.GetSymbol($name, $scopeId, $callerLine, $callerColumn, $MyInvocation).Value)" -ForegroundColor Magenta
	# $val = $sym.Values.Count -gt 0 ? $sym.Values[$sym.Values.Count - 1] : 0
	return [object]$psasm.symbolManager.GetSymbol($name, $scopeId, $callerLine, $callerColumn, $MyInvocation).Value
}
