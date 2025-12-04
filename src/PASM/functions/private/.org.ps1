function .org {
	[PASM()] param (
		[Parameter(Mandatory)]
		[UInt16]$addr
	)
	$pasm.Segments.Current.PC = $addr
}
