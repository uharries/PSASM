class AssemblerInformation {
	[bool]$Success
	[UInt16]$LoadAddress
	[Scope[]]$Scopes
	[object[]]$Symbols
	[object[]]$Segments
	[string]$PSSource
	[array]$SourceMap
	[array]$Assembly
	[string]$AssemblyList
	[byte[]]$Binary
	[string]$BinaryList
	[string]$BinaryHash
	[string]$SegmentInfo

	AssemblerInformation([array]$params) {
		$this.Success = $params.Success
		$this.LoadAddress = $params.LoadAddress
		$this.Scopes = $params.Scopes
		$this.Symbols = $params.Symbols
		$this.Segments = $params.Segments
		$this.PSSource = $params.PSSource
		$this.Assembly = $params.Assembly
		$this.AssemblyList = $params.AssemblyList
		$this.Binary = $params.Binary
		$this.BinaryList = $params.BinaryList
		$this.BinaryHash = $params.BinaryHash
		$this.SegmentInfo = $params.SegmentInfo
	}

	AssemblerInformation() {}
}
