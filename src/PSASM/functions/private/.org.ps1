function .org {
	[PSASM()] param (
		[Parameter(Mandatory)]
		[UInt16]$addr
	)
	$psasm.Segments.Current.SetPC($addr)
}
