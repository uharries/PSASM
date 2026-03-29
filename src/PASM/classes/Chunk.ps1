class Chunk {
	[UInt16]$Start
	[UInt16]$Size
	[bool]$Virtual = $false
	[byte[]]$Bytes

	Chunk([UInt16]$start, [UInt16]$size, [byte[]]$bytes, [bool]$virtual) {
		$this.Start = $start
		$this.Size = $size
		$this.Virtual = $virtual
		$this.Bytes = $bytes
	}
}