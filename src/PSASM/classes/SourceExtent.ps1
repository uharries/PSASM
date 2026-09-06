class SourceExtent {
	[int]$FileId
	[string]$Filename
	[int]$Index
	[int]$Line
	[int]$Column
	[int]$Length

	SourceExtent() {}

	SourceExtent(
		[string]$FileId,
		[string]$Filename,
		[int]$Index,
		[int]$Line,
		[int]$Column,
		[int]$Length
	) {
		$this.FileId = $FileId
		$this.Filename = $Filename
		$this.Index = $Index
		$this.Line = $Line
		$this.Column = $Column
		$this.Length = $Length
	}
}
