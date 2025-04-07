class Parser {
	[Tokenizer]$t
	[Token[]]$inTokens
	[System.Collections.Generic.List[object]]$outTokens
	[System.Collections.Generic.List[object]]$symbols

	Parser([string]$InputData) {
		$this.t = [Tokenizer]::new($InputData)
		$this.inTokens = $this.t.tokens
		$this.outTokens = [System.Collections.Generic.List[Token]]::new()
		$this.symbols = [System.Collections.Generic.List[Token]]::new()
		$this.MapSymbols()
		$this.ParseTokens(0, $this.inTokens.Count)
	}

	Parser() {}

	# [Token] NewToken([string]$value) {
	#     return [Token]::new([TokenType]::Unknown, $value)
	# }

	[void] AddToken([string]$value) {
		$this.outTokens.Add([Token]::new([TokenType]::Unknown, $value))
	}

	[void] InsertToken([int]$index, [string]$value) {
		$this.outTokens.Insert($index, [Token]::new([TokenType]::Unknown, $value))
	}

	[string]GetLabel([Token]$t) {
		return ".label $($t.Value.Trim(':'));"
	}

	[string]ParseLabel([Token]$t) {
		return ".label $($t.Value.Trim(':'));"
	}

	[int] SkipWhitespace([int]$tokenIndex) {
		while($this.inTokens[$tokenIndex].Type -eq [TokenType]::WhiteSpace) {$tokenIndex++}
		return $tokenIndex
	}

	[int] SkipWhitespaceBackwards([int]$tokenIndex) {
		while($this.inTokens[$tokenIndex].Type -eq [TokenType]::WhiteSpace) {$tokenIndex--}
		return $tokenIndex
	}

	[void] MapSymbols() {
		### This updates the Value property of inTokens directly!
		$labels = $this.inTokens.Where({$_.Type -eq [TokenType]::Label}).ForEach({$_.Value = $_.Value.Trim(':');$_})
		$anonymousLabels = $this.inTokens.Where({$_.Type -eq [TokenType]::AnonymousLabel}).ForEach({$_.Value = "ANON_L$($_.Line)_C$($_.Column)";$_})

		$anonymousReferences = foreach($ref in $this.inTokens.Where({$_.Type -eq [TokenType]::AnonymousReference})) {
			if($ref.Value[1] -eq '+') {
				$r = ($anonymousLabels.Where({$_.Index -gt $ref.Index}) | Sort-Object -Property {$_.Index})[$ref.Length-2]
			} else {
				$r = ($anonymousLabels.Where({$_.Index -lt $ref.Index}) | Sort-Object -Descending -Property {$_.Index})[$ref.Length-2]
			}
			$ref.Value = $r.Value
			$ref
		}

		$this.symbols = $labels + $anonymousLabels
	}

	[int] ParseToken([int]$tokenIndex) {
		$token = $this.inTokens[$tokenIndex]
		switch($token.Type) {
			([TokenType]::Label) {
				$j=1
				$inInstr=$false
				while($tokenIndex-$j -ge 0 -and $this.inTokens[$tokenIndex-$j].Type -notin $null, [TokenType]::SemiColon, [TokenType]::NewLine){
					if($this.inTokens[$tokenIndex-$j++].Type -eq [TokenType]::Mnemonic) {
						$this.InsertToken($this.outTokens.Count-$j+1, ".label $($token.Value.Trim(':')) ((.pc) + 1);")
						$inInstr = $true
						break
					}
				}
				if(-not $inInstr) {
					$this.AddToken(".label $($token.Value.Trim(':'));")
				}
			}

			([TokenType]::AnonymousLabel) {
				$j=1
				$inInstr=$false
				while($tokenIndex-$j -ge 0 -and $this.inTokens[$tokenIndex-$j].Type -notin $null, [TokenType]::SemiColon, [TokenType]::NewLine){
					if($this.inTokens[$tokenIndex-$j++].Type -eq [TokenType]::Mnemonic) {
						$this.InsertToken($this.outTokens.Count-$j+1, ".label ANON_L$($token.Line)_C$($token.Column) ((.pc) + 1);")
						$inInstr = $true
						break
					}
				}
				if(-not $inInstr) {
					$this.AddToken(".label ANON_L$($token.Line)_C$($token.Column);")
				}
			}

			# ([TokenType]::AnonymousReference) {
			#     if($token.Value[1] -eq '+') {
			#         $ref = $this.inTokens.Where({$_.Type -eq [TokenType]::AnonymousLabel -and $_.Index -gt $token.Index})[$token.Length-2]
			#     } else {
			#         $ref = ($this.inTokens.Where({$_.Type -eq [TokenType]::AnonymousLabel -and $_.Index -lt $token.Index}) | Sort-Object -Descending -Property {$_.Index})[$token.Length-2]
			#     }
			#     $this.AddToken("`$__SYM_ANON_L$($ref.Line)_C$($ref.Column)")
			# }

			([TokenType]::AnonymousReference) {
				if($token.Value -in $this.symbols.Value) {
					$this.AddToken("`$script:__SYM_$($token.Value)")
				} else {
					$this.AddToken($token.Value)
				}
			}

			([TokenType]::Identifier) {
				if($token.Value -in $this.symbols.Value) {
					$this.AddToken("`$script:__SYM_$($token.Value)")
				} else {
					$this.AddToken($token.Value)
				}
			}

			([TokenType]::CStyleBlockComment) {
				$s = $token.Value
				$s = $s -replace '/\*','<#'
				$s = $s -replace '\*/','#>'
				$this.AddToken($s)
			}

			([TokenType]::CStyleLineComment) {
				$this.AddToken(($token.Value -replace '//',' #'))
			}

			([TokenType]::NumericLiteral) {
				$s = $token.Value
				if($s[0] -eq '$') {$s=$s -replace '[$]','0x'}
				if($s[0] -eq '%') {$s=$s -replace '[%]','0b'}
				$this.AddToken($s)
			}

			([TokenType]::LAngle) {
				$j=1
				while($tokenIndex-$j -ge 0 -and $this.inTokens[$tokenIndex-$j].Type -notin $null, [TokenType]::SemiColon, [TokenType]::NewLine){
					if($this.inTokens[$tokenIndex-$j++].Type -in [TokenType]::Mnemonic, [TokenType]::Directive) {
						$this.AddToken("_loByte ")
						break
					}
				}
			}

			([TokenType]::RAngle) {
				$j=1
				while($tokenIndex-$j -ge 0 -and $this.inTokens[$tokenIndex-$j].Type -notin $null, [TokenType]::SemiColon, [TokenType]::NewLine){
					if($this.inTokens[$tokenIndex-$j++].Type -in [TokenType]::Mnemonic, [TokenType]::Directive) {
						$this.AddToken("_hiByte ")
						break
					}
				}
			}

			([TokenType]::Asterisk) {
				$j=1
				while($tokenIndex-$j -ge 0 -and $this.inTokens[$tokenIndex-$j].Type -notin $null, [TokenType]::SemiColon, [TokenType]::NewLine){
					if($this.inTokens[$tokenIndex-$j++].Type -in [TokenType]::Mnemonic, [TokenType]::Directive) {
						$this.AddToken("(.pc)")
						break
					}
				}
			}

			([TokenType]::Directive) {
				if($token.Value -eq '.macro') {
					$this.AddToken("function")
				} else {
					$this.AddToken($token.Value)
				}
			}

			([TokenType]::Mnemonic) {
				$mne=$token.Value
				$instStartIndex = $tokenIndex+1
				$instEndIndex = $instStartIndex
				$addressingMode = $null

				### Find end of Instruction
				while($this.inTokens[$instEndIndex].Type -notin [TokenType]::CStyleLineComment, [TokenType]::PSLineComment,  [TokenType]::Newline, [TokenType]::SemiColon, [TokenType]::EOF) {
					$instEndIndex++
				}
				### Backtrack whitespaces, to keep trailing whitespace out of Operator parameter
				while($this.inTokens[$instEndIndex-1].Type -eq [TokenType]::Whitespace) {
					$instEndIndex--
				}

				### Skip whitespace after mnemonic
				$tokenIndex = $this.Skipwhitespace(++$tokenIndex)

				$this.AddToken(".inst $($mne)")

				### Relative
				if($mne -in 'BCC','BCS','BEQ','BMI','BNE','BPL','BVC','BVS') {
					$addressingMode = [MOS6502AddressingMode]::Relative
					$this.AddToken(" -AddressingMode $($addressingMode) -Operand (")
					$tokenIndex = $this.ParseTokens($tokenIndex, $instEndIndex-$tokenIndex)
					$this.AddToken(")")
					return $tokenIndex-1
				}

				### Implied
				if($mne -in 'ASL','CLC','CLD','CLI','CLV','DEX','DEY','INX','INY','LSR','NOP','PHA','PHP','PLA','PLP','ROL','ROR','RTI','RTS','SEC','SED','SEI','TAX','TAY','TSX','TXA','TXS','TYA') {
					$addressingMode = [MOS6502AddressingMode]::Implied
					$this.AddToken(" -AddressingMode $($addressingMode)")
					return $tokenIndex-1
				}

				### Rest of the addressing modes
				enum State {Init; Immediate; Absolute; AbsoluteIndexed; AbsoluteIndexedX; AbsoluteIndexedY; Indirect; IndirectAbsolute; IndirectIndexed; IndirectIndexedY; Indexed; IndexedX; IndexedXIndirect}

				$state=[State]::Init
				$operatorTokensIndex=@()
				$parenCount=0
				for($i=$tokenIndex;$i -lt $instEndIndex;$i++) {
					$tk = $this.inTokens[$i]
					switch($tk.Type) {
						([TokenType]::Whitespace) {break}
						([TokenType]::Label) {$operatorTokensIndex+=$i; break}
						([TokenType]::AnonymousLabel) {$operatorTokensIndex+=$i; break}

						([TokenType]::Hash) {
							if($state -eq [state]::Init) {$state = [state]::Immediate; break}
						}

						([TokenType]::LParen) {
							$parenCount++
							if($state -eq [state]::Init) {$state = [state]::Indirect; break}
							$operatorTokensIndex+=$i
						}

						([TokenType]::RParen) {
							if(--$parenCount -eq 0) {
								if($state -eq [state]::Indirect) {$state = [state]::IndirectAbsolute; break}
								if($state -eq [state]::IndexedX) {$state = [state]::IndexedXIndirect; break}
							}
							$operatorTokensIndex+=$i
						}

						([TokenType]::Comma) {
							if($state -eq [state]::Absolute) {$state = [state]::AbsoluteIndexed; break}
							if($state -eq [state]::Indirect) {$state = [state]::Indexed; break}
							if($state -eq [state]::IndirectAbsolute) {$state = [state]::IndirectIndexed; break}
							$operatorTokensIndex+=$i
						}

						{$tk.Value -eq 'x'} {
							if($state -eq [state]::Indexed) {$state = [state]::IndexedX; break}
							if($state -eq [state]::AbsoluteIndexed) {$state = [state]::AbsoluteIndexedX; break}
							$operatorTokensIndex+=$i
						}

						{$tk.Value -eq 'y'} {
							if($state -eq [state]::IndirectIndexed) {$state = [state]::IndirectIndexedY; break}
							if($state -eq [state]::AbsoluteIndexed) {$state = [state]::AbsoluteIndexedY; break}
							$operatorTokensIndex+=$i
						}

						default {
							if($state -eq [state]::Init) {$state = [state]::Absolute}
							$operatorTokensIndex+=$i
						}
					}
				}

				$addressingMode = [MOS6502AddressingMode]$state.ToString()
				$this.AddToken(" -AddressingMode $($addressingMode) -Operand (")
				foreach($i in $operatorTokensIndex) {
					$null = $this.ParseToken($i)
				}
				$this.AddToken(")")
				$tokenIndex = $instEndIndex-1

			}

			default {
				$this.AddToken($token.Value)
			}
		}
		return $tokenIndex
	}

	[int] ParseTokens([int]$tokenIndex, [int]$count) {
		for($i=0;$i -lt $count;$i++) {
			$i = $this.ParseToken($tokenIndex+$i) - $tokenIndex
		}
		return $tokenIndex+$i
	}
}
