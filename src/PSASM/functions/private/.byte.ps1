function .byte {
	[Alias('dc.b')]
	[PSASM()] param (
		[Parameter(Mandatory)]
		[object[]]$values,

		[string]$InvocationFile,
		[int]$InvocationLine,
		[int]$InvocationColumn
	)

	$normalized = foreach ($v in $values) {
		$v -is [Undefined] ? [byte]0 : [byte]($v -band 0xff)
	}
	$psasm.DataAdd($normalized, $InvocationFile, $InvocationLine, $InvocationColumn)
}
