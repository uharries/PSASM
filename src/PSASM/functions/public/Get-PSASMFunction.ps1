<#
	.SYNOPSIS
		Gets the PSASM Assembler function or functions defined.

	.DESCRIPTION
		Gets the PSASM Assembler functions and aliases available for use in the assembler as assembler directives.

	.PARAMETER FunctionName
		The name of the function you want to get or '*' for all.

	.PARAMETER OnlySymbolSupport
		List only PSASM Assembler functions and aliases which support PSASM Assembler symbols as parameters.
		This is used internally by the assembler to filter out specific PSASM Assembler functions for which the assembler should not process symbols, e.g. the .label directive as this rather defines a symbol.

	.EXAMPLE
		Get-PSASMFunction

		Returns an array of System.Management.Automation.CommandInfo objects describing all the PSASM Assembler functions.

	.EXAMPLE
		Get-PSASMFunction -FunctionName .org

		Returns a System.Management.Automation.CommandInfo object describing the .org PSASM Assembler function.

	.OUTPUTS
		System.Management.Automation.CommandInfo - Object or Array describing the matched PSASM Assembler functions.
#>
function Get-PSASMFunction {
	[CmdletBinding()]
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'FunctionName', Justification = 'False positive as rule does not know that Module is used in the BeforeAll scope')]
	param (
		[string]$FunctionName = '*',

		[switch]$OnlySymbolSupport,

		[switch]$ListMacros
	)

	$res = (get-command -Type Function,Alias).Where({
		($_.ScriptBlock.Ast.Body.ParamBlock.Attributes.TypeName.Name -eq "PSASM" -and $_.Name -like $FunctionName) -or
		($_.ResolvedCommand.ScriptBlock.Ast.Body.ParamBlock.Attributes.TypeName.Name -eq "PSASM")
	})

	if ($OnlySymbolSupport) {
		$res = $res.Where({
			($_.ScriptBlock.Ast.Body.ParamBlock.Attributes.NamedArguments.ArgumentName -notmatch 'noSymbolSupport') -and
			($_.ResolvedCommand.ScriptBlock.Ast.Body.ParamBlock.Attributes.NamedArguments.ArgumentName -notmatch 'noSymbolSupport')
		})
	} elseif ($ListMacros) {
		$res = (get-command -Type Function,Alias).Where({
			($_.ScriptBlock.Ast.ParamBlock.Attributes.TypeName.Name -eq "PSASM" -and $_.Name -like $FunctionName)
		})
		$res = $res.Where({
			($_.ScriptBlock.Ast.ParamBlock.Attributes.NamedArguments.ArgumentName -match 'macro')
		})
	}

	return $res
}
