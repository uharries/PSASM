function .byte {
	[Alias('dc.b')]
	[PSASM()] param (
		[Parameter(Mandatory)]
		[int[]]$values,

		[string]$InvocationFile,
		[int]$InvocationLine
	)

	$normalized = foreach ($v in $values) {
		[byte]($v -band 0xff)
	}
	$psasm.DataAdd($normalized, $InvocationFile, $InvocationLine)
}
