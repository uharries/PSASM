function .byte {
	[Alias('dc.b')]
	[PASM()] param (
		[Parameter(Mandatory)]
		[byte[]]$values,

		[string]$InvocationFile,
		[int]$InvocationLine
	)
	$pasm.DataAdd($values, $InvocationFile, $InvocationLine)
}
