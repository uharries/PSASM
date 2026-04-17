function _hiByte {
	[Alias('.hi')]
	[PSASM()] param (
		[Parameter(Mandatory)]
		[int]$value
	)

	$v = $value -band 0xffff
	return [byte]($v -shr 8)
}
