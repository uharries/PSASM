<#
.SYNOPSIS
    Defines a segment in the PSASM Assembler.

.DESCRIPTION
    The .segment function adds a new segment to the assembler if it does not already exist.
    If the segment already exists, it sets it as the current segment and ignores any parameters.
    Segments define memory regions for code and data in the assembly process.

.PARAMETER name
    The name of the segment. This parameter is mandatory.

.PARAMETER Start
    The start address of the segment. If not specified, defaults to -1.
    Cannot be used together with StartAfter.

.PARAMETER StartAfter
    The name of the segment after which this segment should start.
    Cannot be used together with Start.

.PARAMETER End
    The end address of the segment. If not specified, defaults to -1.

.PARAMETER Size
    The size of the segment in bytes. If not specified, defaults to -1.

.PARAMETER Run
    The run address for the segment. Defaults to the Start address.

.PARAMETER Align
    The alignment for the segment. Defaults to 0.

.PARAMETER Fill
    Switch to indicate if the segment should be filled.

.PARAMETER FillByte
    The byte value to use for filling the segment. Defaults to 0.

.PARAMETER AllowOverlap
    Switch to allow overlapping with other segments.

.PARAMETER Virtual
    Switch to mark the segment as virtual.

.EXAMPLE
    .segment -name "code" -Start 0x1000 -End 0x1FFF

    Defines a segment named "code" starting at address 0x1000 and ending at 0x1FFF.

.EXAMPLE
    .segment -name "data" -StartAfter "code" -Size 1024 -Fill -FillByte 0xFF

    Defines a segment named "data" starting after the "code" segment, with a size of 1024 bytes, filled with 0xFF.

.NOTES
    This function is part of the PSASM Assembler.
    Parameter combinations are validated to prevent conflicts.
#>
function .segment {
	[PSASM()] param (
		[Parameter(Mandatory)]
		[string]$name,
		[int]$Start = -1,
		[string]$StartAfter = $null,
		[int]$End = -1,
		[int]$Size = -1,
		[int]$Run = -1,
		[int]$Align = 0,
		[switch]$Fill = $false,
		[byte[]]$FillBytes = @(,0),
		[switch]$AllowOverlap = $false,
		[switch]$Virtual = $false
	)

	if ($psasm.Segments.Segments.ContainsKey($name)) {
		### Set current segment if already defined, ignoring parameters
		$extraParams = @('Start','StartAfter','End','Size','Run','Align','Fill','FillBytes','AllowOverlap','Virtual') | Where-Object { $PSBoundParameters.ContainsKey($_) }
		if ($extraParams.Count -gt 0) {
			# Write-Warning "Segment '$name' already defined. Ignoring parameters: $($extraParams -join ', ')"
		}
	} else {
		### Add segment if not already defined
		$newSegment = [Segment]::New($name)

		if ($End -ge 0 -and $Size -ge 0 -and $Start -lt 0 -and -not $StartAfter) {
			# End and Size, but no Start or StartAfter
			$Start = $End - $Size + 1
		} elseif ($Start -ge 0) {
			# Start specified
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
			# No Start or StartAfter
			$Start = $psasm.Segments.Current.PC
			# throw "Must specify either Start or StartAfter for segment '$name'"
		}

		# if ($Align -lt 0 -and $End -lt 0) {
		# 	throw "Segment '$name' with negative Align requires either -End, -Start and -Size, or -StartAfter and -Size to be specified"
		# }

		$newSegment.StartAddress = $Start
		$newSegment.StartAfter = $StartAfter
		$newSegment.LastAddress = $End
		$newSegment.Size = $Size
		$newSegment.RunAddress = $Run #-lt 0 ? $Start : $Run
		$newSegment.Align = $Align
		$newSegment.Fill = $Fill.IsPresent
		$newSegment.FillBytes = $FillBytes
		$newSegment.AllowOverlap = $AllowOverlap.IsPresent
		$newSegment.Virtual = $Virtual.IsPresent
		$psasm.Segments.Add($newSegment)
	}

	$psasm.Segments.Set($name)
}
