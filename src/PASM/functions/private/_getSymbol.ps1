function _getSymbol {
	[PASM(noSymbolSupport)] param (
		[Parameter(Mandatory)]
		[string]$name,
		[int]$scopeId = 0
	)
	# $val = $sym.Values.Count -gt 0 ? $sym.Values[$sym.Values.Count - 1] : 0
	return [UInt16]$pasm.symbolManager.GetSymbol($name, $scopeId, $MyInvocation).Value
}
