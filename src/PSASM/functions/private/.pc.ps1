function .pc {
	[PSASM()] param (
		[UInt16]$addr
	)

	if ($addr) {
		$psasm.Segments.Current.SetPC($addr)
	} else {
		return $psasm.Segments.Current.GetPC()
	}
}
