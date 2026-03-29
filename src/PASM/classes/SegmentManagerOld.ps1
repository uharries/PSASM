class SegmentManager {
	[hashtable]$Segments = @{
		'default' = @{
			Name		= 'default'
			Base		= 0;
			LogicalBase	= 0;
			StartAfter	= $null;
			Max			= 0xffff;
			Fill		= $false;
			FillByte	= 0x00;
			Align		= 0;
			PC			= 0;
			Virtual		= $false;
			Chunks		= [System.Collections.Generic.List[hashtable]]::new()
		}
	}
	[hashtable]$Current = $this.Segments['default']
	[System.Collections.Stack]$Stack = [System.Collections.Stack]::new()
	[UInt16]$LowestAddress
	[UInt16]$HighestAddress

	SegmentManager() {
	}

	[void] Set([string]$name) {
		if (-not $this.Segments[$name]) {
			throw "Segment '$name' not defined."
		}
		$this.Current = $this.Segments[$name]
	}

	[void] Add([string]$name, [int]$base, [int]$logicalBase, [string]$StartAfter, [int]$max, [bool]$Fill, [int]$FillByte, [int]$Align, [bool]$virtual) {
		if ($this.Segments.ContainsKey($name)) {
			throw "Segment '$name' already defined."
		}
		if ($max -lt $base) {
			throw "Segment '$name' has invalid size: End $('{0:X4}' -f $max) < start $('{0:X4}' -f $base)."
		}
		$this.Segments.Add($name, @{
			Name		= $name
			Base		= $base;
			LogicalBase	= $logicalBase;
			StartAfter	= $StartAfter;
			Max			= $max;
			Fill		= $false;
			FillByte	= 0x00;
			Align		= 0;
			PC			= $logicalBase;
			Virtual		= $virtual;
			Chunks		= [System.Collections.Generic.List[hashtable]]::new()
		})
	}

	[void] Push() {
		$this.Stack.Push($this.Current)
	}

	[void] Pop() {
		if ($this.Stack.Count -eq 0) {
			throw "Segment stack underflow."
		}
		$this.Current = $this.Stack.Pop()
	}

	[void] Emit([byte[]] $bytes) {
		$chunk = @{
			Address	= [UInt16]$this.Current.PC
			Bytes	= $bytes
		}
		$this.Current.Chunks.Add($chunk)
		$this.Current.PC += $bytes.Count
	}

	[void] Reset() {
		foreach ($segment in $this.Segments.Values) {
			$segment.PC = $segment.LogicalBase
			$segment.Chunks.Clear()
		}
	}

	[void] ResolveStartAfter() {
		foreach ($seg in $this.Segments.Values) {
			if ($seg.StartAfter) {

				if (-not $this.Segments.ContainsKey($seg.StartAfter)) {
					throw ".segment $($seg.Name): StartAfter references undefined segment '$($seg.StartAfter)'"
				}

				$ref = $this.Segments[$seg.StartAfter]

				$maxEnd = ($ref.Chunks | ForEach-Object {
					$_.Address + $_.Bytes.Count - 1
				} | Measure-Object -Maximum).Maximum

				# Assign computed start
				#### TODO: Account for Run address!!!!!!!
				$seg.LogicalBase = $maxEnd + 1
				$seg.Base = $seg.LogicalBase
			}
		}
	}


	### TODO: Account for Run address in alignment calculations!!!!
	[void] ApplyAlignmentAndFill() {
		foreach ($seg in $this.Segments.Values) {
			$size = 0
			foreach ($chunk in $seg.Chunks) {
				$size += $chunk.Bytes.Count
			}
			# ALIGNMENT
			if ($seg.Align -gt 0) {
				# Positive alignment -> shift LogicalBase upward
				$a = $seg.Align
				$new = (($seg.LogicalBase + $a - 1) / $a) * $a
				$shift = $new - $seg.LogicalBase
				$seg.LogicalBase = $new
				$seg.Base = $new

				foreach ($chunk in $seg.Chunks) {
					$chunk.Address += $shift
				}
			}
			elseif ($seg.Align -lt 0) {
				# Negative alignment -> align END
				$a = -$seg.Align
				$alignedEnd = $seg.Max - (($seg.Max + 1) % $a)

				$newBase = $alignedEnd - $size + 1

				if ($newBase -lt $seg.Base) {
					throw "Segment '$($seg.Name)' cannot be end-aligned: code does not fit."
				}

				$shift = $newBase - $seg.LogicalBase
				$seg.LogicalBase = $newBase
				$seg.Base = $newBase

				foreach ($chunk in $seg.Chunks) {
					$chunk.Address += $shift
				}
			}
			# FILL
			if ($seg.Fill) {
				$finalEnd = ($seg.Chunks | ForEach-Object {
					$_.Address + $_.Bytes.Count - 1
				} | Measure-Object -Maximum).Maximum

				$targetEnd = $seg.Max

				### TODO: ValidateSegments() catches all overflows, so this is redundant???
				if ($finalEnd -gt $targetEnd) {
					throw "Segment '$($seg.Name)' overflow during fill."
				}

				$fillCount = ($targetEnd - $finalEnd)

				if ($fillCount -gt 0) {
					$seg.Chunks.Add(@{
						Address = $finalEnd + 1
						Bytes   = [byte[]]::new($fillCount)
					})

					if ($seg.FillByte -ne 0) {
						[byte[]]$seg.Chunks[-1].Bytes = @(,$seg.FillByte * $fillCount)
					}
				}
			}
		}
	}

	[void] ValidateSegments() {
		$all = foreach ($segment in $this.Segments.Values) {
			if ($segment.Max + 1 -lt $segment.PC) {
				throw "Segment '$($segment.Name)' overflow: maximum address $('{0:X4}' -f $segment.Max) exceeded (PC is at $('{0:X4}' -f $segment.PC))."
			}
			foreach ($chunk in $segment.Chunks) {
				@{
					Start = [UInt16]($segment.Base + ($chunk.Address - $segment.LogicalBase))
					End   = [UInt16]($segment.Base + ($chunk.Address - $segment.LogicalBase) + $chunk.Bytes.Count - 1)
					Bytes = $chunk.Bytes
				}
			}
		}
		$sorted = @($all | Sort-Object Start)

		# Validate overlaps
		if ($sorted.Count -gt 1) {
			for ($i = 1; $i -lt $sorted.Count; $i++) {
				if ($sorted[$i].Start -le $sorted[$i - 1].End) {
					throw "Memory overlap detected at address `${0:X4}" -f $sorted[$i].Start
				}
			}
		}
	}

	[byte[]] BuildBinary() {
		$this.ResolveStartAfter()
		$this.ApplyAlignmentAndFill()

		$all = foreach ($segment in $this.Segments.Values) {
			if ($segment.Max + 1 -lt $segment.PC) {
				throw "Segment '$($segment.Name)' overflow: maximum address $('{0:X4}' -f $segment.Max) exceeded (PC is at $('{0:X4}' -f $segment.PC))."
			}
			foreach ($chunk in $segment.Chunks) {
				@{
					Start = [UInt16]($segment.Base + ($chunk.Address - $segment.LogicalBase))
					End   = [UInt16]($segment.Base + ($chunk.Address - $segment.LogicalBase) + $chunk.Bytes.Count - 1)
					Bytes = ($segment.Virtual ? $null : $chunk.Bytes)
				}
			}
		}
		$sorted = @($all | Sort-Object Start)

		$this.LowestAddress  = $sorted[0].Start
		$this.HighestAddress = $sorted[-1].End

		# Build final binary
		$finalSize = 0
		if ($sorted.Count -gt 0) {
			$finalSize = $sorted[-1].End - $sorted[0].Start + 1
		}
		$finalBinary = New-Object byte[] $finalSize
		foreach ($chunk in $sorted) {
			if (-not $chunk.Bytes) {
				continue
			}
			[Array]::Copy($chunk.Bytes, 0, $finalBinary, $chunk.Start - $sorted[0].Start, $chunk.Bytes.Count)
		}
		return $finalBinary
	}
}
