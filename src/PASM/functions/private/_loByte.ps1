function _loByte {
	[Alias('.lo')]
	[PASM()] param (
		[Parameter(Mandatory)]
		[int]$value
	)

	return [byte]($value -band 0xff)
}
