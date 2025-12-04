function .segment {
	[PASM()] param (
		[Parameter(Mandatory)]
		[string]$name,
		[UInt16]$Start = 0x0000,
		[UInt16]$Run = $Start,
		[switch]$Virtual = $false
	)
	### Add segment if not already defined and silently ignore parameters if it is defined
	if (-not $pasm.Segments.Segments.ContainsKey($name)) {
		$pasm.Segments.Add($name, $Start, $Run, $Virtual)
	}
	$pasm.Segments.Set($name)
}
