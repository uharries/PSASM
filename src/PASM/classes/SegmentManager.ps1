class SegmentManager {
	[hashtable]$Segments = @{
		'default' = @{
			Name		= 'default'
			Base		= 0;
			LogicalBase	= 0;
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

	[void] Add([string]$name, [int]$base, [int]$logicalBase, [bool]$virtual) {
		if ($this.Segments.ContainsKey($name)) {
			throw "Segment '$name' already defined."
		}
		$this.Segments.Add($name, @{
			Name		= $name
			Base		= $base;
			LogicalBase	= $logicalBase;
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

	[byte[]] BuildBinary() {
		$all = foreach ($segment in $this.Segments.Values) {
			if ($segment.Virtual) {
				continue
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

		$this.LowestAddress  = $sorted[0].Start
		$this.HighestAddress = $sorted[-1].End

		# Validate overlaps
		if ($sorted.Count -gt 1) {
			for ($i = 1; $i -lt $sorted.Count; $i++) {
				if ($sorted[$i].Start -le $sorted[$i - 1].End) {
					throw "Memory overlap detected at address `${0:X4}" -f $sorted[$i].Start
				}
			}
		}

		# Build final binary
		$finalSize = 0
		if ($sorted.Count -gt 0) {
			$finalSize = $sorted[-1].End - $sorted[0].Start + 1
		}
		$finalBinary = New-Object byte[] $finalSize
		foreach ($chunk in $sorted) {
			[Array]::Copy($chunk.Bytes, 0, $finalBinary, $chunk.Start - $sorted[0].Start, $chunk.Bytes.Count)
		}
		return $finalBinary
	}
}
