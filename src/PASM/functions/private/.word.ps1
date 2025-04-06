function .word {
	[Alias('dc.w')]
	[PASM()] param (
		[Parameter(Mandatory)]
		[UInt16[]]$values
	)
	$pasm.DataAdd($values, $MyInvocation)
}
