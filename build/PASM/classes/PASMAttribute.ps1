class PASMAttribute : Attribute {
	[string]$name
	[boolean]$noSymbolSupport

	PASMAttribute([string]$name) {
		$this.name = $name
	}

	PASMAttribute() {}
}
