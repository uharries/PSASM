function .byte {
	[Alias('dc.b')]
	[PASM()] param (
		[Parameter(Mandatory)]
		[byte[]]$values
	)
	$pasm.DataAdd($values, $MyInvocation)
}
