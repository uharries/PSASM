class Token {
	[TokenType]$Type
	[string]$Value
	[int]$Index
	[int]$Length
	[int]$Line
	[int]$Column
	[int]$FileId
	[string]$Filename
	Token([TokenType]$Type,[string]$Value,[int]$Index,[int]$Length,[int]$Line,[int]$Column,[int]$FileId,[string]$Filename) {$this.Type=$Type;$this.Value=$Value;$this.Index=$Index;$this.Length=$Length;$this.FileId=$FileId;$this.Line=$Line;$this.Column=$Column;$this.FileId=$FileId;$this.Filename=$Filename}
	Token([TokenType]$Type,[string]$Value) {$this.Type=$Type;$this.Value=$Value}
	Token() {}
}
