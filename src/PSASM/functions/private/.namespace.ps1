function .namespace {
	[PSASM(noSymbolSupport)]
	param (
		[Parameter(Mandatory)]
		[ValidatePattern("^\w+$")]
		[string]$name
	)

	### Dummy for pre-processed .namespace directive; see SemanticParser class for actual implementation ###
}
