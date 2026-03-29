function .org {
	[PASM()] param (
		[Parameter(Mandatory)]
		[UInt16]$addr
	)
	$pasm.Segments.Current.SetPC($addr)
}
