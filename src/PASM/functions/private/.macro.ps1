
<#
.SYNOPSIS
.macro <name> { [param([...])] <script> }

.DESCRIPTION
Long description

.PARAMETER Name
Parameter description

.PARAMETER Definition
Parameter description

.EXAMPLE
.macro SetBorder { param($color) lda #$color; sta $d020 }

.NOTES
General notes
#>
function .macro {
	[PASM()] param(
		[Parameter(Mandatory)]
		[string]$Signature,  # e.g., "Hello ($name, $age = 5)"
		[Parameter(Mandatory)]
		[scriptblock]$Body
	)

	# Extract function name and optional parameter list
	if ($Signature -match '^\s*([a-z_]\w*)\s*(?:\((.*)\))?.*$') {
		$name = $matches[1]
		$paramList = $matches[2]

		if ($paramList) {
			try {
				[scriptblock]::Create("param($paramList)")
			} catch {
				throw "Line $($MyInvocation.ScriptLineNumber), column $($MyInvocation.OffsetInLine): Invalid parameters in macro definition: $paramList"
			}
		}
	} else {
		throw "Line $($MyInvocation.ScriptLineNumber), column $($MyInvocation.OffsetInLine): Invalid function signature: $Signature"
	}

	# Build the final function code
	if ($paramList) {
		$finalCode = "param($paramList)`n" + $Body.ToString()
	}
	else {
		$finalCode = $Body.ToString()
	}

	$finalBlock = [scriptblock]::Create($finalCode)
	Set-Item "Function:\$name" $finalBlock
}
