function .pc {
	[PASM()] param (
		[UInt16]$addr
	)

	if ($addr) {
		$pasm.Segments.Current.SetPC($addr)
	} else {
		return $pasm.Segments.Current.GetPC()
	}
}
