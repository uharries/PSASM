function .byte {
	[Alias('dc.b')]
	[PSASM()] param (
		[Parameter(Mandatory)]
		[int[]]$values,

		[string]$InvocationFile,
		[int]$InvocationLine
	)

	$normalized = foreach ($v in $values) {
		if ($v -ge -128 -and $v -lt 0) {
			$v += 256
		}
		if ($v -lt 0 -or $v -gt 0xff) {
			throw "File: $InvocationFile, Line: $InvocationLine - Value $v is out of range for a byte."
		}
		[byte]($v -band 0xff)
	}
	$psasm.DataAdd($normalized, $InvocationFile, $InvocationLine)
}
