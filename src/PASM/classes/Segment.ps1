class Segment {
	[string]$Name
	[UInt16]$StartAddress
	[string]$StartAfter
	[UInt16]$EndAddress
	[UInt16]$RunAddress
	[int]$Align
	[bool]$Fill
	[byte]$FillByte
	[UInt16]$Max
	[bool]$Virtual
	[int]$relativePC
	[System.Collections.Generic.List[object]]$Chunks

	Segment([string]$name) {
		$this.Name = $name
		$this.Align = 0
		$this.Fill = $false
		$this.FillByte = 0
		$this.Virtual = $false
		$this.relativePC = 0
		$this.Chunks = [System.Collections.Generic.List[Chunk]]::new()
	}

	[void] AddChunk([Chunk]$chunk) {
		if ($this.Virtual) {
			$chunk.Virtual = $true
		}
		$this.Chunks.Add($chunk)
	}

	[void] ClearChunks() {
		$this.Chunks.Clear()
	}

}
