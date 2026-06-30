function .word {
	[Alias('dc.w')]
	[PSASM()] param (
		[Parameter(Mandatory)]
		[int[]]$values,

		[string]$InvocationFile,
		[int]$InvocationLine
	)

	$normalized = foreach ($v in $values) {
		[UInt16]($v -band 0xffff)
	}

	$psasm.DataAdd($normalized, $InvocationFile, $InvocationLine)
}
