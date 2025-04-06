function _loByte {
	[Alias('.lo')]
	[PASM()] param (
		[Parameter(Mandatory)]
		[UInt16]$value
	)
	return [byte]($value -band 0x00ff)
}
