function .word {
	[Alias('dc.w')]
	[PASM()] param (
		[Parameter(Mandatory)]
		[UInt16[]]$values,

		[string]$InvocationFile,
		[int]$InvocationLine
	)
	$pasm.DataAdd($values, $InvocationFile, $InvocationLine)
}
