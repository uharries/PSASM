function _loByte {
	[Alias('.lo')]
	[PSASM()] param (
		[Parameter(Mandatory)]
		[int]$value
	)

	return [byte]($value -band 0xff)
}
