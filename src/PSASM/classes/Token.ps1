class Token {
	[TokenType]$Type
	[string]$Value
	[SourceExtent]$Extent
	Token([TokenType]$Type,[string]$Value,[SourceExtent]$Extent) {$this.Type=$Type;$this.Value=$Value;$this.Extent=$Extent}
	Token([TokenType]$Type,[string]$Value) {$this.Type=$Type;$this.Value=$Value}
	Token() {}
}
