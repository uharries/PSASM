class AssemblerInformation {
	[bool]$Success
	[UInt16]$LoadAddress
	[Scope[]]$Scopes
	[hashtable]$Symbols
	[string]$PSSource
	[array]$SourceMap
	[array]$Assembly
	[string]$AssemblyList
	[byte[]]$Binary
	[string]$BinaryList
	[string]$BinaryHash

	AssemblerInformation([array]$params) {
		$this.Success = $params.Success
		$this.LoadAddress = $params.LoadAddress
		$this.Scopes = $params.Scopes
		$this.Symbols = $params.Symbols
		$this.PSSource = $params.PSSource
		$this.Assembly = $params.Assembly
		$this.AssemblyList = $params.AssemblyList
		$this.Binary = $params.Binary
		$this.BinaryList = $params.BinaryList
		$this.BinaryHash = $params.BinaryHash
	}

	AssemblerInformation() {}
}
