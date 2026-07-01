class SymbolEntry {
	[string]$Name
	[object]$Value
    [int]$Width
	[string]$ScopeId
	[int]$Pass
    [string]$Filename
	[int]$Line
	[int]$Column

    SymbolEntry([string]$Name, [object]$Value, [int]$Width, [string]$ScopeId, [int]$Pass, [string]$Filename, [int]$Line, [int]$Column) {
        $this.Name = $Name
        $this.Value = $Value
        $this.Width = $width
        $this.ScopeId = $ScopeId
        $this.Pass = $Pass
        $this.Filename = $Filename
        $this.Line = $Line
        $this.Column = $Column
    }

    SymbolEntry () {}
}
