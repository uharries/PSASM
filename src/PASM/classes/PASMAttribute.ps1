class PASMAttribute : Attribute {
	[string]$name
	[boolean]$noSymbolSupport
	[boolean]$macro

	PASMAttribute([string]$name) {
		$this.name = $name
	}

	PASMAttribute() {}
}
