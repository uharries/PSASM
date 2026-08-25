function _hiByte {
	[Alias('.hi')]
	[PSASM()] param (
		[Parameter(Mandatory)]
		[object]$value
	)

	$value = $value -is [Undefined] ? 0 : $value -band 0xffff
	return [byte]($value -shr 8)
}
