function .word {
	[Alias('dc.w')]
	[PSASM()] param (
		[Parameter(Mandatory)]
		[int[]]$values,

		[string]$InvocationFile,
		[int]$InvocationLine
	)

	$normalized = foreach ($v in $values) {
		if ($v -ge -32768 -and $v -lt 0) {
			$v += 65536
		}
		if ($v -lt 0 -or $v -gt 0xffff) {
			throw "File: $InvocationFile, Line: $InvocationLine - Value $v is out of range for a word."
		}
		[UInt16]($v -band 0xffff)
	}

	$psasm.DataAdd($normalized, $InvocationFile, $InvocationLine)
}
