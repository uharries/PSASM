function .pc {
	[PASM()] param (
		[UInt16]$addr
	)

	if ($addr) {
		$pasm.Segments.Current.PC = $addr
	} else {
		return $pasm.Segments.Current.PC
	}
}
