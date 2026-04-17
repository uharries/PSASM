class Chunk {
	[int]$Start
	[int]$Size
	[bool]$Virtual = $false
	[byte[]]$Bytes

	Chunk([int]$start, [int]$size, [byte[]]$bytes, [bool]$virtual) {
		$this.Start = $start
		$this.Size = $size
		$this.Virtual = $virtual
		$this.Bytes = $bytes
	}
}


class Segment {
	[string]$Name			# Name of the segment
	[int]$Order				# Index of the segment in definition order
	[int]$StartAddress		# Get's overwritten/calculated when StartAfter is used
	[string]$StartAfter		# Name of segment that this segment starts after
	[int]$LastAddress		# If specified, segment cannot grow beyond this address
	[int]$Size				# If specified, size of the segment
	[int]$RunAddress		# Address where segment is loaded/executed from
	[int]$Align				# Negative alignment implies fill before alignment from end
	[bool]$Fill				# If true, fills to realEnd with FillByte
	[byte]$FillByte			# Byte to use when filling
	[byte[]]$FillBytes		# Bytes to use when filling
	[bool]$AllowOverlap		# If true, allows other segments to overlap this one. StartAfter implies AllowOverlap on the segment referenced, unless Fill or negative Align is specified on the referenced segtment.
	[bool]$Virtual			# If true, segment is virtual and does not emit bytes
	[int]$PC				# Maintained as $RunAddress + $relativePC
	[int]$relativePC		# Incremented as chunks are added
	[int]$relativeMaxPC		# Tracks the max size reached in this segment
	[int]$realSize			# The actual size of the segment after all chunks have been added and alignment/fill applied
	[int]$realStart			# The actual calculated start address after layout is solved
	[int]$realEnd			# The actual calcullated end address after layout is solved (Not redundant, as realStart may not be known)
	[int]$relativeMinPC		# Lowest address used in this segment
	[int]$contentOffset		# When negative alignment is used, this tracks where the content should be placed within the segment
	[System.Collections.Generic.List[object]]$Chunks	# List of chunks in this segment

	Segment([string]$name) {
		$this.Name = $name
		$this.Align = 0
		$this.Fill = $false
		$this.FillByte = 0
		$this.FillBytes = @(0)
		$this.AllowOverlap = $false
		$this.Virtual = $false
		$this.relativePC = 0
		$this.PC = $this.RunAddress + $this.relativePC
		$this.relativeMaxPC = -1
		$this.relativeMinPC = -1
		$this.realStart = -1
		$this.realSize = -1
		$this.realEnd = -1
		$this.contentOffset = 0
		$this.Chunks = [System.Collections.Generic.List[Chunk]]::new()
	}

	[void] AddChunk([Chunk]$chunk) {
		if ($this.Virtual) {
			$chunk.Virtual = $true
		}
		$this.Chunks.Add($chunk)
		$minPC = $this.relativeMinPC -lt 0 ? $this.relativePC : $this.relativeMinPC
		$this.relativeMinPC = [math]::Min($minPC, $this.relativePC)
		$this.relativePC += $chunk.Size
		$rstart = $this.realStart -lt 0 ? 0 : $this.realStart
		$this.PC = ($this.RunAddress -lt 0) ? ($rstart + $this.relativePC) : ($this.RunAddress + $this.relativePC)
		$maxPC = $this.relativeMaxPC -lt 0 ? $this.relativePC : $this.relativeMaxPC
		$this.relativeMaxPC = [math]::Max($maxPC, $this.relativePC)
	}

	[void] Reset() {
		$this.Chunks.Clear()
		$this.relativePC = 0
		$this.PC = $this.RunAddress -ge 0 ? $this.RunAddress + $this.relativePC : $this.realStart -ge 0 ? $this.realStart + $this.relativePC : $this.relativePC
		$this.relativeMaxPC = -1
		$this.relativeMinPC = -1
	}

	[int] GetEffectiveBaseAddress() {
		# return ($this.RunAddress -lt 0) ? $this.realStart -lt 0 ? $this.StartAddress -lt 0 ? 0 : $this.StartAddress : $this.realStart : $this.RunAddress
		return $this.realStart -lt 0 ? $this.StartAddress -lt 0 ? 0 : $this.StartAddress : $this.realStart
	}

	[void] SetPC([int]$addr) {
		$this.relativePC = $addr - $this.GetEffectiveBaseAddress()
		$this.PC = $addr
	}

	[int] GetPC() {
		return $this.PC
	}

}


class SegmentManager {
	[hashtable]$Segments = @{}
	[Segment]$Current
	[System.Collections.Generic.Stack[Segment]]$Stack
	[int]$LowestAddress
	[int]$HighestAddress
	[int]$nextSegmentOrder = 0

	SegmentManager() {
		$this.Stack = [System.Collections.Generic.Stack[Segment]]::new()
		$newSegment = [Segment]::New("default")
		$newSegment.StartAddress = 0x0000
		$newSegment.StartAfter = $null
		$newSegment.LastAddress = -1
		$newSegment.Size = -1
		$newSegment.RunAddress = -1
		$newSegment.Align = 0
		$newSegment.Fill = $false
		$newSegment.FillByte = 0x00
		$newSegment.FillBytes = @(0x00)
		$newSegment.AllowOverlap = $true
		$newSegment.Virtual = $false
		$newSegment.realStart = -1
		$newSegment.realSize = -1
		$newSegment.realEnd = -1
		$this.Add($newSegment)
		$this.Set("default")
	}

	[void] Add([Segment]$segment) {
		if ($this.Segments.ContainsKey($segment.Name)) {
			throw "Segment '$($segment.Name)' already defined."
		}
		$segment.Order = $this.nextSegmentOrder++
		$this.Segments[$segment.Name] = $segment
	}

	[void] Set([string]$name) {
		if (-not $this.Segments[$name]) {
			throw "Segment '$name' not defined."
		}
		$this.Current = $this.Segments[$name]
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
		$this.Current.AddChunk([Chunk]::new(
			$this.Current.relativePC,
			$bytes.Count,
			$bytes,
			$this.Current.Virtual
		))
	}

	[void] Reset() {
		foreach ($segment in $this.Segments.Values) {
			$segment.Reset()
		}
		$this.Set("default")
	}


	[void] SolveLayout() {
		# Initialize values to run forward solving
		# foreach ($seg in $this.Segments.Values) {
		# 	if ($seg.StartAddress -ge 0) {
		# 		$seg.realStart = $seg.StartAddress
		# 	}
		# }
		$changed = $true
		while ($changed) {
			$changed = $false
			$orderedSegments = $this.Segments.Values | Sort-Object -Property realStart, Order
			foreach ($seg in $orderedSegments) {
				$oldStart = $seg.realStart
				$oldEnd   = $seg.realEnd
				$oldSize  = $seg.realSize

				# Determine minimum size
				### not needed
				$minSize = $seg.relativeMaxPC - $seg.relativeMinPC
				if ($minSize -lt 0) { $minSize = 0 }

				# Determine earliest start
				if ($seg.realStart -ge 0) {
					$start = $seg.realStart
				} elseif ($seg.StartAddress -ge 0) {
					$start = $seg.StartAddress + ($seg.relativeMinPC -lt 0 ? 0 : $seg.relativeMinPC)
				} else {
					$start = $seg.relativeMinPC
				}
				if ( $start -lt 0 ) { $start = 0 }

				# StartAfter override
				if ($seg.StartAfter) {
					$before = $this.Segments[$seg.StartAfter]
					if (-not $before) {
						throw "Unknown StartAfter segment '$($seg.StartAfter)'"
					}
					if ($before.realEnd -lt 0) {
						# cannot resolve yet, skip
						continue
					}
					$start = $before.realEnd + 1
				}

				# Negative Align
				if ($seg.Align -lt 0) {
					# negative align implies fill
					$seg.Fill = $true
					$align = -$seg.Align

					# if LastAddress exists, anchor to it
					if ($seg.LastAddress -ge 0) {
						$latestStart = $seg.LastAddress - $minSize + 1
						$alignedContentStart = $latestStart - ($latestStart % $align)
						$seg.realStart = $seg.StartAddress -ge 0 ? $seg.StartAddress : $alignedContentStart
						$seg.realEnd   = $seg.LastAddress
						$seg.realSize  = $seg.realEnd - $seg.realStart + 1
						# Store where content should go within the segment
						$seg.contentOffset = $alignedContentStart - $seg.realStart
					} else {
						# no LastAddress -> anchor at minimal satisfying page end
						throw "Cannot find end of address space for segment '$($seg.Name)'"
					}
				} else {
					# Positive or no Alignment
					$align = $seg.Align
					$alignedContentStart = $align -gt 0 ? [math]::Ceiling($start / $align) * $align : $start
					$size = $minSize

					# Fill -> LastAddress sets hard end
					if ($seg.Fill -and $seg.LastAddress -ge 0) {
						$end  = $seg.LastAddress
						$size = $end - $start + 1
						$seg.contentOffset = $alignedContentStart - $start
					} elseif ($seg.Fill -and $seg.Size -ge 0) {
						$end  = $start + $seg.Size - 1
						$size = $seg.Size
						$seg.contentOffset = $alignedContentStart - $start
					} else {
						# No fill - alignment moves the segment start itself
						$start = $alignedContentStart
						$end = $start + $size - 1
						$seg.contentOffset = 0
					}
					$seg.realStart = $start
					$seg.realSize  = $size
					$seg.realEnd   = $end
				}
				# detect solved progress
				if ($seg.realStart -ne $oldStart -or
					$seg.realEnd   -ne $oldEnd   -or
					$seg.realSize  -ne $oldSize) {
					$changed = $true
				}
			}
		}
	}

	[byte[]] BuildBinary() {
		$orderedSegments = $this.Segments.Values | Sort-Object -Property realStart, Order

		# Write-Host "Final Segment Layout:"
		# foreach ($segment in $orderedSegments) {
		# 	Write-Host " Segment '$($segment.Name)': Start=0x$('{0:X4}' -f $segment.realStart) Size=0x$('{0:X4}' -f $segment.realSize)"
		# }


		foreach ($seg in $orderedSegments) {
			if ($seg.LastAddress -ge 0 -and $seg.realEnd -gt $seg.LastAddress) {
				throw "Segment '$($seg.Name)' exceeds defined End at 0x$('{0:X4}' -f $seg.LastAddress) with actual end address 0x$('{0:X4}' -f ($seg.realEnd))"
			}
			if ($seg.Size -ge 0 -and $seg.realSize -gt $seg.Size) {
				throw "Segment '$($seg.Name)' exceeds defined Size of 0x$('{0:X4}' -f $seg.Size) with actual size 0x$('{0:X4}' -f $seg.realSize)"
			}
		}


		$binaryStart = [int]::MaxValue
		$binaryEnd   = [int]::MinValue

		foreach ($seg in $orderedSegments) {

			if ($seg.Virtual) { continue }

			# If Fill → segment owns full range
			if ($seg.Fill) {
				$binaryStart = [math]::Min($binaryStart, $seg.realStart)
				$binaryEnd   = [math]::Max($binaryEnd,   $seg.realEnd)
				continue
			}

			# Otherwise → only chunks define emitted range
			foreach ($chunk in $seg.Chunks) {
				if ($chunk.Virtual -or $chunk.Size -le 0) { continue }

				$start = $seg.realStart + ($chunk.Start - $seg.relativeMinPC)
				$end   = $start + $chunk.Size - 1

				$binaryStart = [math]::Min($binaryStart, $start)
				$binaryEnd   = [math]::Max($binaryEnd,   $end)
			}
		}

		if ($binaryStart -gt $binaryEnd) {
			return [byte[]]@()   # nothing emitted anywhere
		}

		$this.LowestAddress = $binaryStart
		$this.HighestAddress = $binaryEnd


		$binSize = $binaryEnd - $binaryStart + 1
		$buffer = New-Object byte[] $binSize

		# Check for overlaps
		for ($i = 0; $i -lt $orderedSegments.Count; $i++) {
				$seg = $orderedSegments[$i]
				if ($seg.realSize -le 0) { continue }
			for ($j = $i-1; $j -ge 0; $j--) {
				$prevSeg = $orderedSegments[$j]
				if ($prevSeg.realSize -le 0) { continue }

				if ($seg.realStart -le $prevSeg.realEnd -and $prevSeg.realStart -le $seg.realEnd) {
					# overlap detected
					if (-not $prevSeg.AllowOverlap) {
						$addr = [math]::Max($seg.realStart, $prevSeg.realStart)
						throw "Segment '$($seg.Name)' overlaps '$($prevSeg.Name)' at address 0x$('{0:X4}' -f $addr)"
					}
				}
			}
		}

		# emit Fill bytes first
		foreach ($seg in $orderedSegments) {
			if (-not $seg.Fill) { continue }
			$fillVal = $seg.FillBytes
			$start   = $seg.realStart - $binaryStart
			$end     = $seg.realEnd   - $binaryStart

			for ($i = $start; $i -le $end; $i++) {
				$buffer[$i] = $fillVal[($i - $start) % $fillVal.Count]
			}
		}

		# emit chunks
		foreach ($seg in $orderedSegments) {
			foreach ($chunk in $seg.Chunks) {
				if ($chunk.Virtual -or $chunk.Size -le 0) { continue }
				$dst = $seg.realStart + $seg.contentOffset + $chunk.Start - $binaryStart
				if ($dst -lt 0 -or ($dst + $chunk.Size) -gt $buffer.Count) {
					### not an error when the layout is still not converged...
					### realStart may have been updated by SolveLayout(),
					### but the Chunk start addresses have not and will not be until next pass.
					### For now, just skip and hope for future pass to resolve
					### ?CONVERGENCE OUT OF NON-COMPLICATED BOUNDS  ERROR!
					### I should probably throw if current pass is > 1....
					continue
				}
				for ($i = 0; $i -lt $chunk.Size; $i++) {
					$buffer[$dst + $i] = $chunk.Bytes[$i]
				}
			}
		}
		return $buffer
	}


	[string] DumpSegments() {
		$orderedSegments = $this.Segments.Values | Sort-Object -Property realStart, Order
		$lines = [System.Collections.Generic.List[string]]::new()

		foreach ($seg in $orderedSegments) {
			$start   = $seg.realStart -ge 0 ? ('$' + ('{0:X4}' -f $seg.realStart)) : '????'
			$end     = $seg.realEnd   -ge 0 ? ('$' + ('{0:X4}' -f $seg.realEnd))   : '????'
			$size    = $seg.realSize  -ge 0 ? ('$' + ('{0:X4}' -f $seg.realSize))  : '????'
			$cur     = $seg.Name -eq $this.Current.Name ? ' *' : '  '
			$content = $seg.relativeMaxPC -lt 0 ? 0 : ($seg.relativeMaxPC - ($seg.relativeMinPC -lt 0 ? 0 : $seg.relativeMinPC))

			$flags = [System.Collections.Generic.List[string]]::new()
			if ($seg.Virtual)      { $flags.Add('Virtual') }
			if ($seg.Fill)         { $flags.Add('Fill') }
			if ($seg.AllowOverlap) { $flags.Add('AllowOverlap') }
			if ($seg.Align -ne 0)  { $flags.Add("Align=$($seg.Align)") }
			if ($seg.RunAddress -ge 0 -and $seg.RunAddress -ne $seg.realStart) {
				$flags.Add('Run=$' + ('{0:X4}' -f $seg.RunAddress))
			}
			if ($seg.StartAfter)   { $flags.Add("StartAfter=$($seg.StartAfter)") }
			$flagStr = $flags.Count -gt 0 ? "  [$($flags -join ', ')]" : ''

			$fillStr = ''
			if ($seg.Fill) {
				$fillStr = '  fill=' + (($seg.FillBytes | ForEach-Object { '$' + ('{0:X2}' -f $_) }) -join ',')
			}

			$name = "$($seg.Name)$cur"
			$lines.Add("  $($name.PadRight(14)) $start..$end  size=$size  content=$('{0:X4}' -f $content)  chunks=$($seg.Chunks.Count)$flagStr$fillStr")
		}

		return "Segments ($($this.Segments.Count)):`n" + ($lines -join "`n")
	}

}