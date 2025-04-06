function .org {
	[PASM()] param (
		[Parameter(Mandatory)]
		[UInt16]$addr
	)
	$pasm.pc = $addr
}
