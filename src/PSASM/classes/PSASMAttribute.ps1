class PSASMAttribute : Attribute {
	[string]$name
	[boolean]$noSymbolSupport
	[boolean]$macro

	PSASMAttribute([string]$name) {
		$this.name = $name
	}

	PSASMAttribute() {}
}
