class SemanticParser {
	[Tokenizer]$t
	[Token[]]$inTokens
	[System.Collections.Generic.List[object]]$outTokens
	[SymbolManager]$symbolManager
	[ScopeManager]$scopeManager
	[System.Collections.Generic.List[object]]$Macros

	SemanticParser([string]$InputData) {
		$this.t = [Tokenizer]::new($InputData)
		$this.symbolManager = [SymbolManager]::new()
		$this.inTokens = $this.t.tokens
		$this.outTokens = [System.Collections.Generic.List[Token]]::new()
		$this.scopeManager = [ScopeManager]::new()
		$this.Macros = [System.Collections.Generic.List[string]]::new()
		$this.MapSymbols()
		$this.MapScopes()
		$this.MapMacros()
		$this.ParseTokens(0, $this.inTokens.Count)
	}

	SemanticParser() {}

	# [Token] NewToken([string]$value) {
	#     return [Token]::new([TokenType]::Unknown, $value)
	# }

	[void] AddToken([string]$value) {
		$this.outTokens.Add([Token]::new([TokenType]::Unknown, $value))
	}

	[void] InsertToken([int]$index, [string]$value) {
		$this.outTokens.Insert($index, [Token]::new([TokenType]::Unknown, $value))
	}

	[int] SkipWhitespace([int]$tokenIndex) {
		while($this.inTokens[$tokenIndex].Type -eq [TokenType]::WhiteSpace) {$tokenIndex++}
		return $tokenIndex
	}

	[int] SkipWhitespaceBackwards([int]$tokenIndex) {
		while($this.inTokens[$tokenIndex].Type -eq [TokenType]::WhiteSpace) {$tokenIndex--}
		return $tokenIndex
	}

	hidden [int] LookBackForToken([int]$startIndex, [TokenType[]]$stopTypes, [TokenType[]]$matchTypes, [bool]$skipParenthesis) {
		$i = 1
		$depth = 0

		while ($startIndex - $i -ge 0) {
			$token = $this.inTokens[$startIndex - $i]

			if ($skipParenthesis) {
				if ($token.Type -eq [TokenType]::RParen) {
					$depth++
					$i++
					continue
				}
				elseif ($token.Type -eq [TokenType]::LParen) {
					if ($depth -gt 0) {
						$depth--
						$i++
						continue
					}
				}
			}

			# Only consider stopTypes when outside parentheses
			if ($depth -eq 0 -and $token.Type -in $stopTypes) {
				break
			}

			# Only check for matchTypes outside parentheses
			if ($depth -eq 0 -and $token.Type -in $matchTypes) {
				return $startIndex - $i
			}

			$i++
		}

		return -1
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

		($labels + $anonymousLabels).ForEach({
			$this.symbolManager.AddUnscopedSymbol($_.Value)
		})
	}

	[void] MapScopes() {
		for ($tokenIndex = 0; $tokenindex -lt $this.inTokens.Count; $tokenIndex++) {
			$token = $this.inTokens[$tokenIndex]
			switch($token.Type) {
				([TokenType]::LCurly) {
					$matchedIndex = $this.LookBackForToken($tokenIndex, @([TokenType]::LCurly, [TokenType]::RCurly, [TokenType]::Pipe), @([TokenType]::Label, [TokenType]::AnonymousLabel, [TokenType]::Identifier), $true)
					if ($matchedIndex -ge 0) {
						$this.scopeManager.EnterNewScope($this.inTokens[$matchedIndex].Value, $tokenIndex, $token.Line, $token.Column)
					} else {
						$this.scopeManager.EnterNewScope($tokenIndex, $token.Line, $token.Column)
					}
				}

				([TokenType]::RCurly) {
					$this.scopeManager.ExitNewScope($tokenIndex, $token.Line, $token.Column)
				}

				([TokenType]::EOF) {
					$this.scopeManager.ExitNewScope($tokenIndex, $token.Line, $token.Column)
				}
			}
		}
		$this.symbolManager.scopes = $this.scopeManager.scopes
	}

	[void] MapMacros() {
		for ($tokenIndex = 0; $tokenindex -lt $this.inTokens.Count; $tokenIndex++) {
		    $token = $this.inTokens[$tokenIndex]
		    switch($token.Type) {
		        ([TokenType]::Directive) {
		            if ($token.Value -match '\.mac(ro)?') {
		                $j = 1
		                while ($this.inTokens[$tokenIndex+$j].Type -eq [TokenType]::WhiteSpace) {$j++}
		                if ($this.inTokens[$tokenIndex+$j].Type -eq [TokenType]::Identifier) {
		                    $this.Macros.Add($this.inTokens[$tokenIndex+$j].Value)
		                }
		            }
		        }
		    }
		}
	}


	[int] ParseToken([int]$tokenIndex) {
		$token = $this.inTokens[$tokenIndex]
		switch($token.Type) {
			([TokenType]::Label) {
				$j=1
				$inInstr=$false
				$symbolName = $token.Value.Trim(':')
				while($tokenIndex-$j -ge 0 -and $this.inTokens[$tokenIndex-$j].Type -notin $null, [TokenType]::SemiColon, [TokenType]::NewLine){
					if($this.inTokens[$tokenIndex-$j++].Type -eq [TokenType]::Mnemonic) {
						$this.InsertToken($this.outTokens.Count-$j+1, ".label -name $symbolName -scopeId $($this.scopeManager.GetCurrentScope()) -addr ((.pc) + 1);")
						$inInstr = $true
						$this.symbolManager.AddUnresolvedSymbol($symbolName, $this.scopeManager.GetCurrentScope(), $token.Line, $token.Column)
						break
					}
				}
				if(-not $inInstr) {
					$this.AddToken(".label -name $symbolName -scopeId $($this.scopeManager.GetCurrentScope());")
					$this.symbolManager.AddUnresolvedSymbol($symbolName, $this.scopeManager.GetCurrentScope(), $token.Line, $token.Column)
				}
			}

			([TokenType]::AnonymousLabel) {
				$j=1
				$inInstr=$false
				$symbolName = "ANON_L$($token.Line)_C$($token.Column)"
				while($tokenIndex-$j -ge 0 -and $this.inTokens[$tokenIndex-$j].Type -notin $null, [TokenType]::SemiColon, [TokenType]::NewLine){
					if($this.inTokens[$tokenIndex-$j++].Type -eq [TokenType]::Mnemonic) {
						$this.InsertToken($this.outTokens.Count-$j+1, ".label -name $symbolName -scopeId $($this.scopeManager.GetCurrentScope()) -addr ((.pc) + 1);")
						$inInstr = $true
						$this.symbolManager.AddUnresolvedSymbol($symbolName, $this.scopeManager.GetCurrentScope(), $token.Line, $token.Column)
						break
					}
				}
				if(-not $inInstr) {
					$this.AddToken(".label -name $symbolName -scopeId $($this.scopeManager.GetCurrentScope());")
					$this.symbolManager.AddUnresolvedSymbol($symbolName, $this.scopeManager.GetCurrentScope(), $token.Line, $token.Column)
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
				# if($this.symbolManager.TestSymbol($token.Value, $this.scopeManager.GetCurrentScope())) {
					# write-host "AnonymousReference __getSymbol()"
					$this.AddToken(" (_getSymbol '$($token.Value)' $($this.scopeManager.GetCurrentScope()) $($token.Line) $($token.Column))")
					# $this.AddToken("`$script:__SYM_$($token.Value)")
				# } else {
					# $this.AddToken($token.Value)
				# }
			}

			([TokenType]::Identifier) {
				$tval = $token.Value
				$ti = $tokenIndex
				while ($this.inTokens[$ti+1].Type -eq [TokenType]::Member) {
					$ti++
					$tval += $this.inTokens[$ti].Value
				}
				if($this.symbolManager.TestSymbol($tval, $this.scopeManager.GetCurrentScope())) {
					# $this.AddToken("`(_getSymbol '$($tval)' $($this.scopeManager.GetCurrentScope()) $($token.Line) $($token.Column))")
					# write-host "Identifier __getSymbol()"
					$this.AddToken(' (_getSymbol "'+$($tval)+'" '+$($this.scopeManager.GetCurrentScope())+' '+$($token.Line)+' '+$($token.Column)+')')
					$tokenIndex = $ti
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

			([TokenType]::LCurly) {
				$this.scopeManager.EnterScope($tokenIndex)
				$this.AddToken($token.Value)
			}

			([TokenType]::RCurly) {
				$this.scopeManager.ExitScope()
				$this.AddToken($token.Value)
			}

			([TokenType]::LParen) {
				$i = $tokenIndex+1
				while($this.inTokens[$i].Type -eq [TokenType]::WhiteSpace) {
					$i++
				}
				if ($this.inTokens[$i].Type -eq [TokenType]::RParen) {
					$i = $tokenIndex-1
					while($this.inTokens[$i].Type -eq [TokenType]::WhiteSpace) {
						$i--
					}
					if ($this.inTokens[$i].Value -in $this.Macros) {
						$this.AddToken(" @")
					} elseif ($this.inTokens[$i].Type -eq [TokenType]::Identifier) {
						$i--
						while($this.inTokens[$i].Type -eq [TokenType]::WhiteSpace) {
							$i--
						}
						if ($this.inTokens[$i].Type -eq [TokenType]::Directive) {
							if ($this.inTokens[$i].Value -match '\.mac(ro)?') {
								$this.AddToken(" @")
							}
						}
					}
				}
				$this.AddToken($token.Value)
			}

			([TokenType]::Asterisk) {
				$match = $false
				$j=1
				while($tokenIndex-$j -ge 0 -and $this.inTokens[$tokenIndex-$j].Type -notin $null, [TokenType]::SemiColon, [TokenType]::NewLine){
					if($this.inTokens[$tokenIndex-$j++].Type -in [TokenType]::Mnemonic, [TokenType]::Directive) {
						$k=1
						while($tokenIndex-$k -ge 0 -and $this.inTokens[$tokenIndex-$k].Type -notin [TokenType]::Mnemonic, [TokenType]::Directive){
							if($this.inTokens[$tokenIndex-$k].Type -in [TokenType]::Whitespace) {
								$k++
								continue
							}
							if($this.inTokens[$tokenIndex-$k++].Type -in [TokenType]::Comma, [TokenType]::Divide, [TokenType]::Equals, [TokenType]::LAngle, [TokenType]::RAngle, [TokenType]::LParen, [TokenType]::Minus, [TokenType]::Modulo, [TokenType]::Plus, [TokenType]::Asterisk) {
								$this.AddToken("(.pc)")
							} else {
								$this.AddToken($token.Value)
							}
							$match = $true
							break
						}
						if(-not $match) {
							$this.AddToken("(.pc)")
							$match = $true
						}
						break
					}
				}
				if(-not $match) {
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
				$operandTokensIndex=@()
				$parenCount=0
				for($i=$tokenIndex;$i -lt $instEndIndex;$i++) {
					$tk = $this.inTokens[$i]
					switch($tk.Type) {
						([TokenType]::Whitespace) {break}
						([TokenType]::Label) {$operandTokensIndex+=$i; break}
						([TokenType]::AnonymousLabel) {$operandTokensIndex+=$i; break}

						([TokenType]::Hash) {
							if($state -eq [state]::Init) {$state = [state]::Immediate; break}
						}

						([TokenType]::LParen) {
							$parenCount++
							if($state -eq [state]::Init) {$state = [state]::Indirect; break}
							$operandTokensIndex+=$i
						}

						([TokenType]::RParen) {
							if(--$parenCount -eq 0) {
								if($state -eq [state]::Indirect) {$state = [state]::IndirectAbsolute; break}
								if($state -eq [state]::IndexedX) {$state = [state]::IndexedXIndirect; break}
							}
							$operandTokensIndex+=$i
						}

						([TokenType]::Comma) {
							if($state -eq [state]::Absolute) {$state = [state]::AbsoluteIndexed; break}
							if($state -eq [state]::Indirect) {$state = [state]::Indexed; break}
							if($state -eq [state]::IndirectAbsolute) {$state = [state]::IndirectIndexed; break}
							$operandTokensIndex+=$i
						}

						{$tk.Value -eq 'x'} {
							if($state -eq [state]::Indexed) {$state = [state]::IndexedX; break}
							if($state -eq [state]::AbsoluteIndexed) {$state = [state]::AbsoluteIndexedX; break}
							$operandTokensIndex+=$i
						}

						{$tk.Value -eq 'y'} {
							if($state -eq [state]::IndirectIndexed) {$state = [state]::IndirectIndexedY; break}
							if($state -eq [state]::AbsoluteIndexed) {$state = [state]::AbsoluteIndexedY; break}
							$operandTokensIndex+=$i
						}

						default {
							if($state -eq [state]::Init) {$state = [state]::Absolute}
							$operandTokensIndex+=$i
						}
					}
				}

				$addressingMode = [MOS6502AddressingMode]$state.ToString()
				$this.AddToken(" -AddressingMode $($addressingMode) -Operand (")

				# write-Host $operandTokensIndex
				# foreach ($t in $operandTokensIndex) {
				# 	write-host $this.inTokens[$t].Type, $this.inTokens[$t].Value
				# }
				for($i=0;$i -lt $operandTokensIndex.Count;$i++) {
					$ti = $this.ParseToken($operandTokensIndex[$i])
					while($i -lt $operandTokensIndex.Count -and $ti -ge $operandTokensIndex[$i+1]) {$i++}
				}
				$this.AddToken(")")
				$tokenIndex = $instEndIndex-1

			}

			([TokenType]::EOF) {
				$this.scopeManager.ExitScope()
				$this.AddToken($token.Value)
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
