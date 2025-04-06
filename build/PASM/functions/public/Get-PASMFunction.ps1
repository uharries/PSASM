<#
	.SYNOPSIS
		Gets the PASM function or functions defined.

	.DESCRIPTION
		Gets the PASM functions and aliases available for use in the PASM assembler as assembler directives.

	.PARAMETER FunctionName
		The name of the function you want to get or '*' for all.

	.PARAMETER OnlySymbolSupport
		List only PASM functions and aliases which support PASM Symbols as parameters.
		This is used internally by the assembler to filter out specific PASM functions for which the assembler should not process symbols, e.g. the .label directive as this rather defines a symbol.

	.EXAMPLE
		Get-PASMFunction

		Returns an array of System.Management.Automation.CommandInfo objects describing all the PASM functions.

	.EXAMPLE
		Get-PASMFunction -FunctionName .org

		Returns a System.Management.Automation.CommandInfo object describing the .org PASM function.

	.OUTPUTS
		System.Management.Automation.CommandInfo - Object or Array describing the matched PASM functions.
#>
function Get-PASMFunction {
	[CmdletBinding()]
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'FunctionName', Justification = 'False positive as rule does not know that Module is used in the BeforeAll scope')]
	param (
		[string]$FunctionName = '*',

		[switch]$OnlySymbolSupport
	)

	$res = (get-command -Type Function,Alias).Where({
		($_.ScriptBlock.Ast.Body.ParamBlock.Attributes.TypeName.Name -eq "PASM" -and $_.Name -like $FunctionName) -or
		($_.ResolvedCommand.ScriptBlock.Ast.Body.ParamBlock.Attributes.TypeName.Name -eq "PASM")
	})

	if($OnlySymbolSupport) {
		$res = $res.Where({
			($_.ScriptBlock.Ast.Body.ParamBlock.Attributes.NamedArguments.ArgumentName -notmatch 'noSymbolSupport') -and
			($_.ResolvedCommand.ScriptBlock.Ast.Body.ParamBlock.Attributes.NamedArguments.ArgumentName -notmatch 'noSymbolSupport')
		})
	}

	return $res
}
