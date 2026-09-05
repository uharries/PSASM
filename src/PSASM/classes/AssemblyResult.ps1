class AssemblyResult {
	[bool]$Success
	[string]$ErrorMessage
	[UInt16]$LoadAddress
	[object[]]$Scopes
	[object[]]$Symbols
	[object[]]$SymbolsFull
	[string]$PSSource
	[object[]]$Segments
	[string]$SegmentInfo
	[array]$Assembly
	[string]$AssemblyList
	[byte[]]$Binary
	[string]$BinaryList
	[string]$BinaryHash
	[Token[]]$Tokens

	AssemblyResult() {}
}
