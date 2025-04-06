function .label {
	[Alias('.lab')]
	[PASM(noSymbolSupport)]	param (
		[Parameter(Mandatory)]
		[ValidatePattern("^\w+$")]
		# [ValidateScript({!$pasm.symbols[$_].resolved}, ErrorMessage="Symbol '{0}' already defined!")]
		[string]$label,

		[UInt16]$addr = $pasm.pc
	)

	if($pasm.CurrentPass -eq 1 -and $pasm.symbols[$label].resolved) {
		if($pasm.symbols["$($label)__1"]) {
			$rx = "$($label)__\d+"
			$label = "$($label)__$([int]$pasm.symbols.GetEnumerator().Where({$_.Name -match $rx}).Key.Split("__")[-1]+1)"
		} else {
			$label = "$($label)__1"
		}
		if(-not $pasm.symbols[$label]) {
			$pasm.symbols[$label] = @{}
		}
	}
	$pasm.symbols[$label].value = $addr
	$pasm.symbols[$label].width = 16
	$pasm.symbols[$label].resolved = $true

	# Set a $__sym_labelname variable in the parent's parent scope, which should be the ScriptBlock encasing the psSource to value - allows for more native PS handling when symbols are involved
	Set-Variable -Name "__SYM_$label" -Value $addr -Scope Script
}
