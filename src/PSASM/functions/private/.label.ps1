function .label {
	[Alias('.lab')]
	[PSASM(noSymbolSupport)]	param (
		[Parameter(Mandatory)]
		[ValidatePattern("^\w+$")]
		# [ValidateScript({!$psasm.symbols[$_].resolved}, ErrorMessage="Symbol '{0}' already defined!")]
		[string]$name,
		[int]$scopeId,

		[object]$addr = [UInt16]$psasm.Segments.Current.PC
	)

	# Write-Host ".label(name='$name', scopeId=$scopeId, addr=$addr)" -ForegroundColor Magenta

	# write-host $addr.GetType().FullName -ForegroundColor DarkGray
	# write-host $addr.PSObject.BaseObject.GetType().FullName -ForegroundColor DarkGray

	# Sometimes it's an Int32, sometimes a UInt16 - but can also be a scriptblock or another random object.
	# Thus, I may need to validate it better than this.. maybe throw if it's a valuetype > 16 bits?
	# Alternatively, I could just change SymbolEntry to store [object] as value.. maybe that's even better and would allow to store macros in the symboltable as well?
	if ($addr -is [ValueType]) {
		$width = $addr -ge 256 ? 16 : 8
	} else {
		# $addr = 0
		$width = 0
	}
	# write-host "`nGetSymbol($name,$scopeId)"
	$oldSym = $psasm.symbolManager.GetSymbol($name, $scopeId, 0,0, $MyInvocation)
	# write-host "Name: $($oldSym.Name)"
	# write-host "Value: $($oldSym.Value)"
	# write-host "Width: $($oldSym.Width)"
	# write-host "ScopeId: $($oldSym.ScopeId)"
	# write-host "Pass: $($oldSym.Pass)"
	# write-host "Line: $($oldSym.Line)"
	# write-host "Column: $($oldSym.Column)"
	$sym = [SymbolEntry]::new($name, $addr, $width, $scopeId, $psasm.CurrentPass, $oldSym.Line, $oldSym.Column)

	# write-host "  .label: SetSymbol(sym={name=$name, addr=$addr, width=$width, scopeId=$scopeId, pass=$($psasm.CurrentPass), line=$($oldSym.Line), column=$($oldSym.Column)})" -ForegroundColor Magenta
	$psasm.symbolManager.SetSymbol($sym)

	# $psasm.symbols[$label].value = $addr
	# $psasm.symbols[$label].width = 16
	# $psasm.symbols[$label].resolved = $true
}
