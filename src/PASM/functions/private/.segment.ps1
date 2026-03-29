function .segment {
	[PASM()] param (
		[Parameter(Mandatory)]
		[string]$name,
		[int]$Start = -1,
		[string]$StartAfter = $null,
		[int]$End = -1,
		[int]$Size = -1,
		[int]$Run = $Start,
		[int]$Align = 0,
		[switch]$Fill = $false,
		[byte]$FillByte = 0,
		[switch]$AllowOverlap = $false,
		[switch]$Virtual = $false
	)
	### Add segment if not already defined and silently ignore parameters if it is defined
	if (-not $pasm.Segments.Segments.ContainsKey($name)) {
		$newSegment = [Segment]::New($name)

		# End and Size, but no Start
		if ($End -ge 0 -and $Size -ge 0 -and $Start -lt 0 -and -not $StartAfter) {
			$Start = $End - $Size + 1
		} elseif ($Start -ge 0) {
			if (-not $StartAfter) {
				if ($End -ge 0 -and $Size -ge 0) {
					throw "Cannot specify both End and Size when Start is specified for segment '$name'"
				}
				if ($End -ge 0) {
					$Size = $End - $Start + 1
				} elseif ($Size -ge 0) {
					$End = $Start + $Size - 1
				} else {
					# No End or Size - Should I throw?
					#throw "Must specify either End or Size when Start is specified for segment '$name'"
				}
			} else {
				throw "Cannot specify both Start and StartAfter for segment '$name'"
			}
		} elseif ($StartAfter) {
			if ($End -ge 0 -and $Size -ge 0) {
				throw "Cannot specify both End and Size when StartAfter is specified for segment '$name'"
			}
		} else {
			$Start = $pasm.Segments.Current.PC
		}

		$newSegment.StartAddress = $Start
		$newSegment.StartAfter = $StartAfter
		$newSegment.LastAddress = $End
		$newSegment.Size = $Size
		$newSegment.RunAddress = $Run
		$newSegment.Align = $Align
		$newSegment.Fill = $Fill.IsPresent
		$newSegment.FillByte = $FillByte
		$newSegment.AllowOverlap = $AllowOverlap.IsPresent
		$newSegment.Virtual = $Virtual.IsPresent
		$pasm.Segments.Add($newSegment)
	}
	$pasm.Segments.Set($name)
}
