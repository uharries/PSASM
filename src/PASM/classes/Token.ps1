class Token {
	[TokenType]$Type
	[string]$Value
	[int]$Index
	[int]$Length
	[int]$Line
	[int]$Column
	Token([TokenType]$Type,[string]$Value,[int]$Index,[int]$Length,[int]$Line,[int]$Column) {$this.Type=$Type;$this.Value=$Value;$this.Index=$Index;$this.Length=$Length;$this.Line=$Line;$this.Column=$Column}
	Token([TokenType]$Type,[string]$Value) {$this.Type=$Type;$this.Value=$Value}
	Token() {}
}
