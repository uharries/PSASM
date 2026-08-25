function _loByte {
	[Alias('.lo')]
	[PSASM()] param (
		[Parameter(Mandatory)]
		[object]$value
	)
	$value = $value -is [Undefined] ? [byte]0 : [byte]($value -band 0xff)
	return $value
}
