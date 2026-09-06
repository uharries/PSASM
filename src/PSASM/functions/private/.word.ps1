function .word {
	[Alias('dc.w')]
	[PSASM()] param (
		[Parameter(Mandatory)]
		[object[]]$values,

		[string]$InvocationFile,
		[int]$InvocationLine,
		[int]$InvocationColumn
	)

	$normalized = foreach ($v in $values) {
		$v -is [Undefined] ? [UInt16]0 : [UInt16]($v -band 0xffff)
	}

	$psasm.DataAdd($normalized, $InvocationFile, $InvocationLine, $InvocationColumn)
}
