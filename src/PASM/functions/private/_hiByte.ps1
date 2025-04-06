function _hiByte {
	[Alias('.hi')]
	[PASM()] param (
		[Parameter(Mandatory)]
		[UInt16]$value
	)
	return [byte](($value -band 0xff00) / 256)
}
