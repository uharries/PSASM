function .pc {
	[PASM()] param (
		[UInt16]$addr
	)

	if ($addr) {
		$pasm.pc = $addr
	} else {
		return $pasm.pc
	}
}
