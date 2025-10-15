function .macro {
	[Alias('.mac')]
	[PASM()] param(
		[Parameter(Mandatory=$true, Position=0)]
		[string]$Name,

		[Parameter(ValueFromRemainingArguments = $true)]
		[object[]]$MacroArgs,

		[int]$ScopeID = 0
	)

	if ($MacroArgs.Count -eq 0) {
		throw "Macro '$Name' requires a scriptblock body"
	}

	# Last argument is always the body
	$Body = $MacroArgs[-1]
	if (-not ($Body -is [scriptblock])) {
		throw "Last argument must be a scriptblock in macro '$Name'"
	}

	# Get raw call text so we can preserve literal $params
	$callText = $MyInvocation.Statement
	# write-host ".macro Invocation Statement: $($callText)"
	# Extract "(...)" part if present
	if ($callText -match '\w+\s*\((.*?)\)\s*\{') {
		$ParamList = $matches[1].Trim()
		$ParamNames = foreach ($p in ($ParamList -split '\s*,\s*')) {
			if ($p -match '^(?<name>\$\w+)(?:\s*=\s*(?<default>.+))?$') {
				# write-host "pName: $($matches['name'])"
				# write-host "pDefault: $($matches['default'])"
				[pscustomobject]@{
					Name    = $matches['name']
					Default = $matches['default']
				}
			}
		}
	} else {
		$ParamList = ""
		$ParamNames = @()
	}

	# Extract body text
	$BodyText = $Body.Ast.Extent.Text
	if ($BodyText.StartsWith('{') -and $BodyText.EndsWith('}')) {
		$BodyText = $BodyText.Substring(1, $BodyText.Length - 2).Trim()
	}

	# Build the unpacking code
	$UnpackCode = ""
	$numDefault = 0
	if ($ParamNames.Count -gt 0) {		### So if 0 arguments, you are allowed to pass any number of arguments, which can then be accessed via $args.
		$assignments = @()
		for ($i=0;$i -lt $($ParamNames.Count);$i++) {
			$pName = $ParamNames[$i].Name
			$pDefault = $ParamNames[$i].Default
			if ($pDefault) {
				$numDefault++
				$assignments += 'if($macroArgs.Count -gt ' + $i + ') { ' + $pName + ' = $macroArgs[' + $i + '] } else { ' + $pName + ' = $(' + $pDefault + ') }'
			} else {
				$assignments += "$pName = `$macroArgs[$i]"
			}
		}
		$UnpackCode = @"
	if (`$macroArgs.Count -lt $($ParamNames.Count - $numDefault) -or `$macroArgs.Count -gt $($ParamNames.Count)) {
		throw "Incorrect number of arguments passed to macro '$Name'. Expected $($ParamNames.Count), got `$(`$macroArgs.Count)."
	}
	$($assignments -join "`n")
"@
	}

	# Build function definition
	$FunctionText = if ([string]::IsNullOrWhiteSpace($ParamList)) {
		$BodyText
	} else {
		"[PASM(macro)] param([object[]]`$macroArgs)`n$UnpackCode`n$BodyText"
	}

	$sb = [scriptblock]::Create($FunctionText)
	# set-item "Function:\script:$Name" -Value $sb

	$pasm.Macros[$ScopeID] ?? ($pasm.Macros[$ScopeID] = [ordered]@{})

	$pasm.Macros[$ScopeID][$Name] = $sb
# 	$msg = Get-Item "Function:\$Name" | fl | Out-String
# 	write-host $msg
}