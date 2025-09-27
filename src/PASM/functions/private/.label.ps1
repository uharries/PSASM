function .label {
	[Alias('.lab')]
	[PASM(noSymbolSupport)]	param (
		[Parameter(Mandatory)]
		[ValidatePattern("^\w+$")]
		# [ValidateScript({!$pasm.symbols[$_].resolved}, ErrorMessage="Symbol '{0}' already defined!")]
		[string]$name,
		[int]$scopeId,

		[UInt16]$addr = $pasm.pc
	)

	$width = $addr -ge 256 ? 16 : 8
	# write-host "`nGetSymbol($name,$scopeId)"
	$oldSym = $pasm.symbolManager.GetSymbol($name, $scopeId, 0,0, $MyInvocation)
	# write-host "Name: $($oldSym.Name)"
	# write-host "Value: $($oldSym.Value)"
	# write-host "Width: $($oldSym.Width)"
	# write-host "ScopeId: $($oldSym.ScopeId)"
	# write-host "Pass: $($oldSym.Pass)"
	# write-host "Line: $($oldSym.Line)"
	# write-host "Column: $($oldSym.Column)"
	$sym = [SymbolEntry]::new($name, $addr, $width, $scopeId, $pasm.CurrentPass, $oldSym.Line, $oldSym.Column)

	# write-host "SetSymbol($name, $addr, $width, $scopeId, $($pasm.CurrentPass), $($oldSym.Line), $($oldSym.Column))"
	$pasm.symbolManager.SetSymbol($sym)

	# $pasm.symbols[$label].value = $addr
	# $pasm.symbols[$label].width = 16
	# $pasm.symbols[$label].resolved = $true

	# # Set a $__sym_labelname variable in the parent's parent scope, which should be the ScriptBlock encasing the psSource to value - allows for more native PS handling when symbols are involved
	# Set-Variable -Name "__SYM_$label" -Value $addr -Scope Script
}
