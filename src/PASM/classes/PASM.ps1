#using module .\AssemblyLine.psm1
#using module .\MOS6502.ps1

enum PASMType {
	label
	anonymousLabel
	anonymousReference
	symbol
	symbolReference
	instruction
	directive
	macro
	macroCall
}

class PASM {
    [UInt16]$pc
    [UInt16]$loadAddress
	[hashtable]$symbols
	[System.Collections.ArrayList]$assembly
	[string]$asmSource
	[string[]]$workSource
	[string]$psSource
	[byte[]]$binary
	[string]$binaryHash
	[int]$MaxPasses = 10
	[int]$CurrentPass = 0
	[hashtable]$sourceMap
	[bool]$NoHostOutput
	[Parser]$parser

	PASM() {
		$this.Init()
	}

	PASM([string]$asmSource, [bool]$NoHostOutput) {
		$this.Init()
		# $this.asmSource = $asmSource.Split([char[]]("`n","`r"),[System.StringSplitOptions]::RemoveEmptyEntries)
		$this.asmSource = $asmSource
		# $this.workSource = $this.asmSource.Clone()
		$this.NoHostOutput = $NoHostOutput
	}

	hidden [void]Init() {
		$this.pc = 0
		$this.loadAddress = 0x0000
		$this.symbols = [ordered] @{
			____load_addr = @{
				value = $this.loadAddress
				width = 16
				resolved = $true			### Need to find clever way to "actually" resolve this
			}
		}
		$this.assembly = [System.Collections.ArrayList]@()
		$this.sourceMap = @{}
	}

	[void]AddLine([UInt16]$addr, [byte[]]$bytes, [System.Management.Automation.InvocationInfo]$invocation) {
		$this.assembly.Add([AssemblyLine]::new($addr, $bytes, $invocation.ScriptLineNumber, $invocation.OffsetInLine, ($this.sourceMap.pasmCalls + $this.sourceMap.instructions).Where({$_.Line -eq $invocation.ScriptLineNumber})[0].Text, $invocation.Line.Trim(), $invocation.ScriptName))
	}

	[void]OpAdd([byte]$OpCode, [System.Management.Automation.InvocationInfo]$invocation) {
		$this.AddLine($this.pc, @($OpCode), $invocation)
		$this.pc++
	}

	[void]OpAdd([byte]$OpCode, [byte]$Operand, [System.Management.Automation.InvocationInfo]$invocation) {
		$this.AddLine($this.pc, @($OpCode,$Operand), $invocation)
		$this.pc+=2
	}

	[void]OpAdd([byte]$OpCode, [UInt16]$Operand, [System.Management.Automation.InvocationInfo]$invocation) {
		$this.AddLine($this.pc, @($OpCode,(_loByte $Operand),(_hiByte $Operand)), $invocation)
		$this.pc+=3
	}

	[void]DataAdd([byte[]]$data, [System.Management.Automation.InvocationInfo]$invocation) {
		$this.AddLine($this.pc, $data, $invocation)
		$this.pc+=$data.Count
	}

	[void]DataAdd([UInt16[]]$data, [System.Management.Automation.InvocationInfo]$invocation) {
		$this.AddLine($this.pc, [byte[]]($data | ForEach-Object{_loByte $_;_hiByte $_}), $invocation)
		$this.pc+=$data.Count*2
	}

	[void]MapSource() {
		$labels = @()
		$anonymousLabels = @()
		$anonymousReferences = @()
		$symbolReferences = @()
		$instructions = @()
		$directives = @()
		$macros = @()
		$macroCalls = @()

		# Line comment regex used in most other regex'es
		$rxComment = '(?<!(?://|^\s*#).*)'
		# Symbol references - Used on Operand/Parameters
		### This one checks for too much which is already filtered out... and also does not handle symbols between strings...
		### ...maybe balancing groups can be used cleverly to identify if in string or between strings...
		### ...alternative method required, or find a pattern that matches asdf and NOT "asdf" without relying on capture groups
		### so group 0 can be used and thus a simple -replace can do the work.
		# $rxSymbol = "$($rxComment)(?<![\$.-])(?<=\b)(?!\d)(\w+)(?![:])(?=\b)(?((?<=([""']).*?\1)(?=.*?\2))(?!))" # Group 1: Symbol (only for use on Operand/Parameters)
		# took a different approach, where i first find all symbols (really only labels for now) and then just match on those - see $rxSymbols further down

		# Map labels, anonymous labels and anonymous label references
		$rxLabel = "$($rxComment)((?<=\b)(?<![\.$-])(?!($([MOS6502]::OpCodes.keys -join "|"))[:])(\w+)[:])"
		$LinesWithLabels = $this.workSource | Select-String -Pattern $rxLabel -AllMatches
		foreach ($line in $LinesWithLabels) {
			foreach ($match in $line.Matches) {
				$labels += [pscustomobject]@{
					Type = [PASMType]::label
					Line = $line.LineNumber
					Offset = $match.Groups[1].Index
					Length = $match.Groups[1].Length
					Value = $match.Groups[1].Value.Trim(':')
				}
			}
		}
		$rxAnonymousLabel = "$($rxComment)((?<!\w+|[?].*?|[\]:])[:](?![+-]))"
		$LinesWithAnonymousLabels = $this.workSource | Select-String -Pattern $rxAnonymousLabel -AllMatches
		foreach ($line in $LinesWithAnonymousLabels) {
			foreach ($match in $line.Matches) {
				$anonymousLabels += [pscustomobject]@{
					Type = [PASMType]::anonymousLabel
					Line = $line.LineNumber
					Offset = $match.Groups[1].Index
					Length = $match.Groups[1].Length
					Value = ("ANON_L{0}_C{1}" -f ($line.LineNumber), ($match.Groups[0].Index+1))
				}
			}
		}

		# Create symbol table and ps vars for all labels
		($labels + $anonymousLabels).ForEach({
			$this.symbols.Add($_.Value, [ordered]@{
				value = $null
				width = 16
				resolved = $false
				references = @()
			})
			Set-Variable -Name "__SYM_$($_.Value)" -Value 0x0000 -Scope Script
		})

		$rxAnonymousReference = "$($rxComment)([:]([+-])(\2*))"	# Group 1: all, Group 2: Fw/back, Group 3: How many - 1
		$LinesWithAnonymousReferences = $this.workSource | Select-String -Pattern $rxAnonymousReference -AllMatches
		foreach ($line in $LinesWithAnonymousReferences) {
			foreach ($match in $line.Matches) {
				$fwRef = $match.Groups[2].Value -eq '+' ? $true : $false
				if ($fwRef) {
					$ref = ($anonymousLabels.GetEnumerator().Where({$_.Value -match '^ANON_L' -and ($_.Line -gt $line.LineNumber -or ($_.Line -eq $line.LineNumber -and $_.Offset -gt $match.Groups[1].Index))}) | Sort-Object -Property {$_.Line}, {$_.Offset})[$match.Groups[3].Length]
				} else {
					$ref = ($anonymousLabels.GetEnumerator().Where({$_.Value -match '^ANON_L' -and ($_.Line -lt $line.LineNumber -or ($_.Line -eq $line.LineNumber -and $_.Offset -lt $match.Groups[1].Index))}) | Sort-Object -Descending -Property {$_.Line}, {$_.Offset})[$match.Groups[3].Length]
				}
				$o = [pscustomobject]@{
					Type = [PASMType]::anonymousReference
					Line = $line.LineNumber
					Offset = $match.Groups[1].Index
					Length = $match.Groups[1].Length
					Value = $ref.Value
				}
				$this.symbols.Item($ref.Value).references += $o
				$anonymousReferences += $o
			}
		}

		$rxSymbols = "(?<!\.label\s+|//.*?)(?<=\b)($($this.symbols.Keys -join '|'))(?=\b)(?![:])"
		$LinesWithSymbolReferences = $this.workSource | Select-String -Pattern $rxSymbols -AllMatches
		foreach ($line in $LinesWithSymbolReferences) {
			foreach ($match in $line.Matches) {
				$o = [pscustomobject]@{
					Type = [PASMType]::symbolReference
					Line = $line.LineNumber
					Offset = $match.Groups[1].Index
					Length = $match.Groups[1].Length
					Value = $match.Groups[1].Value -replace $rxSymbols, '$$script:__SYM_$1'
				}
				write-host $match.Groups[1].Value
				$this.symbols.Item($match.Groups[1].Value).references += $o
				$symbolReferences += $o
			}
		}

		# Find .macro definitions and then map calls to these macros
		$rxMacro = "$($rxComment)((?<=\b)(?<=\.macro\s+)(\w+)(?=\b))"
		$macros = foreach ($line in $this.workSource | Select-String -Pattern $rxMacro -AllMatches) {
			foreach ($match in $line.Matches) {
				[pscustomobject]@{
					Type = [PASMType]::macro
					Name = $match.Groups[1].Value
				}
			}
		}
		if($macros.Count -gt 0) {
			$rxMacroCall = "$($rxComment)((?<=^|\W)(?<![\$.]|\.macro\s+)(?:$($macros.Name -join '|'))(?=\b))[^\S\r\n]*((?:.*?)(?=(?:[;\r\n]+|\s*//|$)))" # Group 1: macro name, Group 2: Parameters
			$LinesWithMacroCalls = $this.workSource | Select-String -Pattern $rxMacroCall -AllMatches
			foreach ($line in $LinesWithMacroCalls) {
				foreach ($match in $line.Matches) {
					$macroCalls += [pscustomobject]@{
						Type = [PASMType]::macroCall
						Line = $line.LineNumber
						Offset = $match.Groups[0].Index
						Length = $match.Groups[0].Length
						Text = $match.Groups[0].Value
						Directive = $match.Groups[1].Value
						Parameters = $match.Groups[2].Value -replace $rxAnonymousReference, ($anonymousReferences.Where({$_.Line -eq $line.LineNumber -and $_.Offset -ge $match.Groups[2].Index -and $_.Offset -lt $match.Groups[2].Index + $match.Groups[2].Length}))[0].Value -replace $rxSymbols,  '$$script:__SYM_$1'
					}
				}
			}
		}

		# Map assembler directives - The -OnlySymbolSupport is used to filter out the .label directive specifically for now.
		$rxDirective = "$($rxComment)((?<=^|\W)(?<![\$])(?:$((Get-PASMFunction -OnlySymbolSupport).Name -join '|' -replace '\.','\.'))(?=\b))[^\S\r\n]*((?:.*?)(?=(?:[;\r\n]+|//|$)))" # Group 1: Directive, Group 2: Parameters
		$LinesWithDirectives = $this.workSource | Select-String -Pattern $rxDirective -AllMatches
		foreach ($line in $LinesWithDirectives) {
			foreach ($match in $line.Matches) {
				$directives += [pscustomobject]@{
					Type = [PASMType]::directive
					Line = $line.LineNumber
					Offset = $match.Groups[0].Index
					Length = $match.Groups[0].Length
					Text = $match.Groups[0].Value
					Directive = $match.Groups[1].Value
					Parameters = $match.Groups[2].Value -replace $rxAnonymousReference, ($anonymousReferences.Where({$_.Line -eq $line.LineNumber -and $_.Offset -ge $match.Groups[2].Index -and $_.Offset -lt $match.Groups[2].Index + $match.Groups[2].Length}))[0].Value -replace $rxSymbols,  '$$script:__SYM_$1'
				}
			}
		}

		# Map assembler instructions, i.e. mnemonics and operands
		$rxMnemonic = "(?<=\b)(?<![\$-])(?:$([MOS6502]::OpCodes.keys -join "|"))(?=\b)"
		$rxInstruction = "$($rxComment)($($rxMnemonic))[^\S\r\n]*((?:.*?)(?=(?:[;\r\n]+|\s*//|$)))"	# Group 1: Mnemonic, Group 2: Operand
		$LinesWithInstructions = $this.workSource | Select-String -Pattern $rxInstruction -AllMatches
		$matchGroupMnemonic = 1
		$matchGroupOperand = 2
		foreach ($line in $LinesWithInstructions) {
			foreach ($match in $line.Matches) {
				$operand = ""
				$addressingMode = $null
				if ($match.Groups[$matchGroupMnemonic] -match "($([MOS6502]::OpCodes.GetEnumerator().Where({$_.Value.Relative}).Name -join '|'))") {
					$addressingMode = [MOS6502AddressingMode]::Relative
					$operand = $match.Groups[$matchGroupOperand].Value.Trim()
				} else {
					switch -Regex ($match.Groups[$matchGroupOperand].Value.Trim()) {
						### Implied Addressing Mode?
						'^$' {
							$addressingMode = [MOS6502AddressingMode]::Implied
							$operand = $null
							break
						}
						### Immediate Addressing Mode?
						'.*?#' {
							$addressingMode = [MOS6502AddressingMode]::Immediate
							$operand = ($match.Groups[$matchGroupOperand] | Select-String '.*?#(.*)').Matches.Groups[1].Value.Trim();
							break
						}
						### Indirect Indexed Y Addressing Mode? ( lda (zp),y )
						'.*?\(.*?\)\s*,\s*y' {
							$addressingMode = [MOS6502AddressingMode]::IndirectIndexedY
							$operand = ($match.Groups[$matchGroupOperand] | Select-String '.*?\((.*?)\)').Matches.Groups[1].Value.Trim();
							break
						}
						### Indexed X Indirect Addressing Mode? ( lda (zp,x) )
						'.*?\(.*?,\s*x\s*\)' {
							$addressingMode = [MOS6502AddressingMode]::IndexedXIndirect
							$operand = ($match.Groups[$matchGroupOperand] | Select-String '.*?\((.*?),').Matches.Groups[1].Value.Trim();
							break
						}
						### Indirect Absolute Addressing Mode? ( jmp (addr) )
						'.*?\(.*?\)' {
							$addressingMode = [MOS6502AddressingMode]::IndirectAbsolute
							$operand = ($match.Groups[$matchGroupOperand] | Select-String '.*?\((.*?)\)').Matches.Groups[1].Value.Trim();
							break
						}
						### Absolute Indexed X Addressing Mode? ( lda addr,x )
						'.*?,\s*[x]' {
							$addressingMode = [MOS6502AddressingMode]::AbsoluteIndexedX
							$operand = ($match.Groups[$matchGroupOperand] | Select-String '(.*?),').Matches.Groups[1].Value.Trim();
							break
						}
						### Absolute Indexed Y Addressing Mode? ( lda addr,y )
						'.*?,\s*[y]' {
							$addressingMode = [MOS6502AddressingMode]::AbsoluteIndexedY
							$operand = ($match.Groups[$matchGroupOperand] | Select-String '(.*?),').Matches.Groups[1].Value.Trim();
							break
						}
						### Anything else = Absolute Addressing Mode assumed ( lda addr )
						default {
							$addressingMode = [MOS6502AddressingMode]::Absolute
							$operand = $match.Groups[$matchGroupOperand].Value.Trim()
							break
						}
					}
				}

				$instructions += [pscustomobject]@{
					Type = [PASMType]::instruction
					Line = $line.LineNumber
					Offset = $match.Groups[0].Index
					Length = $match.Groups[0].Length
					Text = $match.Groups[0].Value
					MnemonicOffset = $match.Groups[1].Index
					MnemonicLength = $match.Groups[1].Length
					Mnemonic = $match.Groups[1].Value.Trim()
					OperandOffset = $match.Groups[2].Index
					OperandLength = $match.Groups[2].Length
					OperandText = $match.Groups[2].Value
					Operand = $operand -replace $rxAnonymousReference, ($anonymousReferences.Where({$_.Line -eq $line.LineNumber -and $_.Offset -ge $match.Groups[2].Index -and $_.Offset -lt $match.Groups[2].Index + $match.Groups[2].Length}))[0].Value -replace $rxSymbols,  '$$script:__SYM_$1'
					AddressingMode = $addressingMode
				}
			}
		}

		# ($macroCalls + $directives).ForEach({($_.Parameters | Select-String -Pattern '[$](__SYM_(\w+))' -AllMatches).ForEach({
		# 	foreach ($match in $_.Matches) {
		# 		$this.symbols.Add($match.Groups[2].Value, [ordered]@{
		# 			value = $null
		# 			width = 16
		# 			resolved = $false
		# 		})
		# 		Set-Variable -Name $match.Groups[1].Value -Value 0x0000 -Scope 2
		# 	}
		# })})

		# foreach ($symbol in $labels + $anonymousLabels) {
		# 	if($symbol.Value) {
		# 		$this.symbols.Add($symbol.Value, [ordered]@{
		# 				value = $null
		# 				width = $null
		# 				resolved = $false
		# 		})
		# 	}
		# }

		$this.sourceMap.Add("labels", $labels)
		$this.sourceMap.Add("anonymousLabels", $anonymousLabels)
		$this.sourceMap.Add("anonymousReferences", $anonymousReferences)
		$this.sourceMap.Add("symbolReferences", $symbolReferences)
		$this.sourceMap.Add("instructions", $instructions)
		$this.sourceMap.Add("directives", $directives)
		$this.sourceMap.Add("macros", $macros)
		$this.sourceMap.Add("macroCalls", $macroCalls)
		# $labels,$anonymousLabels,$anonymousReferences,$symbolReferences,$instructions,$directives,$macros,$macroCalls
	}


	[void]ConvertToPS() {
		$lineNum = 0
		$dataToPatch = $this.sourceMap.labels + $this.sourceMap.anonymousLabels + $this.sourceMap.instructions + $this.sourceMap.directives + $this.sourceMap.macroCalls
		$dataToPatch
		$this.workSource = foreach ($line in $this.workSource) {
			$lineNum++
			$offset = 0
			$lastCmdEnd = 0
			$prev = 0
			$func = $null
			$cmd = $dataToPatch.Where({$_.Line -eq $lineNum}) | Sort-Object Offset
			for ($i=0; $i -lt $cmd.Count; $i++) {
				if (($cmd[$i].Type -eq [PASMType]::label) -or ($cmd[$i].Type -eq [PASMType]::anonymousLabel)) {
					if ($cmd[$i].Offset -lt $lastCmdEnd) {					# still in instruction?
						$func = ".label $($cmd[$i].Value) ((.pc) + 1);"	# Create label at the address following the opcode
						$line = $line.Remove($prev), $func, $line.Remove(0, $prev) -join ""
						$offset += $func.Length
						continue
					} else {
						$prev = $cmd[$i].Offset + $offset
						$func = ".label $($cmd[$i].Value);"
					}
				} else {
					$prev = $cmd[$i].Offset + $offset
					if(($cmd[$i].Type -eq [PASMType]::directive) -or ($cmd[$i].Type -eq [PASMType]::macroCall)) {
						$func = "$($cmd[$i].Directive) $($cmd[$i].Parameters)"
					}

					if($cmd[$i].Type -eq [PASMType]::instruction) {
						if ($cmd[$i].addressingMode -eq [MOS6502AddressingMode]::Implied) {
							$func = ".inst -Mnemonic $($cmd[$i].Mnemonic) -AddressingMode $($cmd[$i].AddressingMode)"
						} else {
							$func = ".inst -Mnemonic $($cmd[$i].Mnemonic) -AddressingMode $($cmd[$i].AddressingMode) -Operand ($($cmd[$i].Operand))"
						}
					}

				}
				if(-not $func) { throw [System.Exception]::new(("Unhandled PASMType {0}" -f $cmd[$i].Type ))}
				$line = $line.Remove($prev), $func, $line.Remove(0, $cmd[$i].Offset + $cmd[$i].Length + $offset) -join ""
				$offset += [math]::Abs($func.Length - $cmd[$i].Length)
				$lastCmdEnd = $cmd[$i].Offset + $cmd[$i].Length
			}
			$line
		}

		# Replace remaining anonymous references.. this is stooopid double work.. need to optimize
		$rxComment = '(?<!(?://|^\s*#).*)'
		$rxAnonymousReference = "$($rxComment)([:]([+-])(\2*))"	# Group 1: all, Group 2: Fw/back, Group 3: How many - 1
		$LinesWithAnonymousReferences = $this.workSource | Select-String -Pattern $rxAnonymousReference -AllMatches
		foreach ($line in $LinesWithAnonymousReferences) {
			foreach ($match in $line.Matches) {
				$fwRef = $match.Groups[2].Value -eq '+' ? $true : $false
				if ($fwRef) {
					$ref = ($this.sourceMap.anonymousLabels.GetEnumerator().Where({$_.Value -match '^ANON_L' -and ($_.Line -gt $line.LineNumber -or ($_.Line -eq $line.LineNumber -and $_.Offset -gt $match.Groups[1].Index))}) | Sort-Object -Property {$_.Line}, {$_.Offset})[$match.Groups[3].Length]
				} else {
					$ref = ($this.sourceMap.anonymousLabels.GetEnumerator().Where({$_.Value -match '^ANON_L' -and ($_.Line -lt $line.LineNumber -or ($_.Line -eq $line.LineNumber -and $_.Offset -lt $match.Groups[1].Index))}) | Sort-Object -Descending -Property {$_.Line}, {$_.Offset})[$match.Groups[3].Length]
				}
				$this.workSource[$line.LineNumber-1] = $this.workSource[$line.LineNumber-1].Substring(0,$match.Groups[0].Index) + $this.workSource[$line.LineNumber-1].Substring($match.Groups[0].Index, $match.Length).Replace($match.Value, "`$script:__SYM_$($ref.Value)") + $this.workSource[$line.LineNumber-1].Substring($match.Groups[0].Index + $match.Length)
			}
		}

		# And the same stooopid replacing of symbols everywhere remaining
		$rxSymbols = "(?<!\.label\s+)(?<=\b)($($this.symbols.Keys -join '|'))(?=\b)(?![:])"
		$LinesWithSymbolReferences = $this.workSource | Select-String -Pattern $rxSymbols -AllMatches
		foreach ($line in $LinesWithSymbolReferences) {
			foreach ($match in $line.Matches) {
				$this.workSource[$line.LineNumber-1] = $this.workSource[$line.LineNumber-1].Substring(0,$match.Groups[0].Index) + $this.workSource[$line.LineNumber-1].Substring($match.Groups[0].Index, $match.Length).Replace($match.Value, "`$script:__SYM_$($match.Groups[0].Value)") + $this.workSource[$line.LineNumber-1].Substring($match.Groups[0].Index + $match.Length)
			}
		}

		# write-host $this.workSource
	}

	[Parser]Parse() {
		$this.parser = [Parser]::new($this.asmSource)
		$this.psSource = $this.parser.outTokens.value -join ''

		# Create symbol table and ps vars for all labels
		$this.parser.symbols.GetEnumerator().ForEach({
			$this.symbols.Add($_.Value, [ordered]@{
				value = $null
				width = 16
				resolved = $false
				references = @()
			})
			Set-Variable -Name "__SYM_$($_.Value)" -Value 0x0000 -Scope Script
		})
		return $this.parser
	}

	[void]ParseOld() {
		$this.workSource = $this.workSource -replace '/\*', '<#'									# Replace C style block comment start with PowerShell block comment start
		$this.workSource = $this.workSource -replace '\*/', '#>'									# Replace C style block comment end with PowerShell block comment end
		# Block comments pose a problem for MapSource if they contain mnemonics or labels or references,
		# so clear out block comments, preserving length and line breaks, thus line numbers which are needed for listing
		if (($this.workSource | Out-String) -match '(?s)<#(.*?)#>') {
			$innerContent = $matches[1] -replace '\S', '#';
			$this.workSource = (($this.workSource | Out-String) -replace '(?s)(<#)(.*?)(#>)', ('$1' + $innerContent + '$3')).Split("`r`n")
		}
		$this.MapSource()
		$this.ConvertToPS()

		$this.workSource = $this.workSource -replace '//', ' #'										# Replace C++ style line comment with PowerShell line comment

		$this.workSource = $this.workSource -replace '<(?![#])', '_loByte '						# Replace < with _loByte function call, except if it is the start of PowerShell block comment
		$this.workSource = $this.workSource -replace "(?<=($([MOS6502]::OpCodes.GetEnumerator().Where({$_.Value.Immediate}).Name -join '|'))\s*[#])>", '_hiByte '	# Replace > with _hiByte function call, if it follows an Immediate addressing mode instruction.
		$this.workSource = $this.workSource -replace "(?<![#])>", '_hiByte '						# Replace > with _hiByte function call, if it does not immediately follow a '#', meaning not a PowerShell block comment end.

		$this.workSource = $this.workSource -replace '\$([0-9a-f]{1,4})(?!\w+)', '0x$1'				# Replace $ with 0x for 4 digit hex numbers (makes it impossible to have PS variables named $0 - $ffff)
		$this.workSource = $this.workSource -replace '(^|\s+)\.macro(\s+.*)', '$1function$2'		# Replace .macro with function statements (simple... but do we need more?)
		$this.workSource = $this.workSource -replace "(($([MOS6502]::OpCodes.keys -join '|')).*?)(\*)", '$1 (.pc) '									# Replace * address references with $pasm.pc

		$this.psSource = $this.workSource.Clone()
	}

	[AssemblerInformation]Assemble() {
		$success=$false
		$bin=[System.Collections.Generic.List[byte]]::new()

		for ($i=1; $i -le $this.MaxPasses -and $success -ne $true; $i++) {
			$this.CurrentPass = $i
			if(-not $this.NoHostOutput) {
				# Write-Progress -Activity "Assembly" -Status "Pass $($i)" -PercentComplete 0
				Write-Host "Pass $($i)..." -NoNewline
			}
			$this.assembly.Clear()
			$this.pc = 0
			$error.Clear()
			$psError=$null

			try {
				$sb = [ScriptBlock]::Create(($this.psSource | out-string))
			} catch {
				if(-not $this.NoHostOutput) {
					Write-Host " FAILED!"
				}
				throw $_
				# throw [System.Exception]::new(("Error in psSource line {0}, column {1}: {2}: {3} '{4}'" -f
				# 	$_.Exception.InnerException.ErrorRecord.InvocationInfo.ScriptLineNumber,
				# 	$_.Exception.InnerException.ErrorRecord.InvocationInfo.OffsetInLine,
				# 	$_.Exception.InnerException.ErrorRecord.CategoryInfo.Category,
				# 	$_.Exception.InnerException.ErrorRecord.FullyQualifiedErrorId,
				# 	$_.Exception.InnerException.ErrorRecord.InvocationInfo.Statement
				# 	))
				# throw [System.Exception]::new(("Syntax Error: {0}") -f $_)
			}

			try {
				Invoke-Command -ScriptBlock $sb -ErrorAction Stop -ErrorVariable psError -NoNewScope
			} catch {
				# Write-Error -Message ("Error in psSource line {0}, column {1}: {2} '{3}' {4}" -f $error[0].InvocationInfo.ScriptLineNumber, $error[0].InvocationInfo.OffsetInLine, $error[0].CategoryInfo.Reason, $error[0].CategoryInfo.TargetName, $error[0].Exception.Message)
				# Write-Error -Message ("Error in psSource line {0}, column {1}: {2} '{3}'" -f $error[0].InvocationInfo.ScriptLineNumber, $error[0].InvocationInfo.OffsetInLine, $error[0].CategoryInfo.Reason, $error[0].CategoryInfo.TargetName) -ErrorAction Stop
				if ($psError) {
					if(-not $this.NoHostOutput) {
						Write-Host " FAILED!"
					}
					throw $_
					# throw [System.Exception]::new(("Error in psSource line {0}, column {1}: {2} '{3}'" -f $psError[0].InvocationInfo.ScriptLineNumber, $psError[0].InvocationInfo.OffsetInLine, $psError[0].CategoryInfo.Reason, $psError[0].CategoryInfo.TargetName))
				} else {
					throw $_
				}
			}
			# not quite sure what to do with errors and the $error object here yet...

			$this.loadAddress = $this.assembly[0].addr
			$bin.Clear()
			$bin.Add(([byte]($this.loadAddress -band 255)))
			$bin.Add(([byte](($this.loadAddress / 256) -band 255)))
			$addrCnt = $this.loadAddress
			foreach ($l in $this.assembly) {
				if($l.addr - $addrCnt -gt 0) {
					# Fill out empty space in binary - 0x00 should be a configurable fillbyte var...
					$bin.AddRange([byte[]]@(0x00) * ($l.addr - $addrCnt))
				}
				$bin.AddRange($l.bytes)
				$addrCnt = $l.addr + $l.bytes.count
			}

			$oldHash = $this.binaryHash
			$this.binaryHash = [System.BitConverter]::ToString([System.Security.Cryptography.SHA256CryptoServiceProvider]::new().ComputeHash($bin)) -replace '-',''
			if(-not $this.NoHostOutput) {
				# Write-Progress -Activity "Assembly" -Status "Pass $($i)" -PercentComplete (100 / $this.MaxPasses * $i)
				Write-Host (" OK! - Hash: {0}" -f $this.binaryHash)
			}
			if ($this.binaryHash -eq $oldHash) {
				if ($this.symbols.Values.resolved -contains $false) {
					$s = "'" + ($this.symbols.GetEnumerator().Where({!$_.Value.resolved -and $_.Value.references}).Name -join "', '") + "'"
					# throw [System.Exception]::new("Unable to resolve symbols: $s")
					Write-Warning -Message "Unresolved symbols defined: $s"
					# break
				}
				$this.binary = $bin.ToArray()
				$success = $true
			}
		}
		if(-not $this.NoHostOutput) {
			# Write-Progress -Activity "Assembly" -Status "Pass $($i)" -PercentComplete 100
		}
		if (!$success) {
			throw [System.Exception]::new("Maximum number of passes exceeded: $($this.MaxPasses)")
		}

		$asmInfoParams = @{
			Success = $true
			LoadAddress = $this.loadAddress
			Symbols = $this.symbols
			PSSource = $this.psSource | Out-String
			SourceMap = $this.sourceMap
			Assembly = $this.assembly
			AssemblyList = $this.ListAssembly()
			Binary = $this.binary
			BinaryList = $this.HexDump()
			BinaryHash = $this.binaryHash
		}

		return ([AssemblerInformation]::new($asmInfoParams))
	}

	###
	### Assembly Lister
	###
	[string]ListAssembly() {
		$sb = [System.Text.StringBuilder]::new(1024)
		$sbl = [System.Text.StringBuilder]::new(64)
		for ($lin=0;$lin -lt $this.assembly.count; $lin++) {
			$a = ("{0:x4}" -f $this.assembly[$lin].addr)
			$sbl.Clear()
			for ($i=0; $i -lt $this.assembly[$lin].bytes.Count; $i++) {
				$sbl.AppendFormat("{0:x2} ", $this.assembly[$lin].bytes[$i])
			}
			$ln = $this.assembly[$lin].lineNumber
			$col = $this.assembly[$lin].charPosition
			$c = ("{0}" -f $this.assembly[$lin].psLineText.Trim())
			$d = ("{0}" -f $this.assembly[$lin].asmLineText.Trim())
			$sb.AppendFormat("`${0,-4}: {1,-9}- Ln: {2,-3} Col: {3,-3} - {4} - {5}", $a, $sbl.ToString(), $ln, $col, $d, $c)
			$sb.AppendLine()
		}
		return $sb.ToString()
	}


	###
	### Binary Hex Dumper - Yes, I forgot PS has a Format-Hex command, but mine is neater ;-)
	###
	[string]HexDump() {
		$sb = [System.Text.StringBuilder]::new(1024)
		for ($i=0;$i -lt $this.binary.count; $i+=16) {
			$sb.AppendFormat("`${0:x4}: ", $i)
			$j=0
			for (; $i+$j -lt $this.binary.count -and $j -lt 16; $j++) {
				$sb.AppendFormat("{0:x2} ", $this.binary[$i+$j])
			}
			while ($j++ -lt 16) {
				$sb.Append("   ")
			}

			$sb.Append("  '")
			for ($j=0; $i+$j -lt $this.binary.count -and $j -lt 16; $j++) {
				$sb.AppendFormat("{0}", ((($this.binary[$i+$j] -ge 32 -and $this.binary[$i+$j] -lt 127)) ? ([char]$this.binary[$i+$j]) : ('.')) )
			}
			$sb.AppendLine("'")
		}
		return $sb.ToString()
	}
}
