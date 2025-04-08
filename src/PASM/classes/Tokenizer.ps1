class Tokenizer {

	[string]$InputData
	[int]$cpos
	[hashtable]$lineMap
	[int]$tokenStart
	# [System.Collections.Generic.List[Token]]$tokens
	[System.Collections.Generic.List[Object]]$tokens # Apparently does not work properly when specifying the class...
	# $tokens


	Tokenizer([string]$InputData) {
		[int]$l=1
		$this.lineMap = @{$l = 0}
		$this.InputData = $InputData
		$this.cpos = 0
		$this.tokenStart = 0
		$this.tokens = [System.Collections.Generic.List[Token]]::new()

		for($i=0;$i -lt $InputData.Length;$i++) {
			if($InputData[$i] -eq "`r") {
				if($InputData[$i+1] -lt $InputData.Length -and $InputData[$i+1] -eq "`n") {
					$i++
				}
				$this.lineMap.Add(++$l, $i+1)
			} elseif($InputData[$i] -eq "`n") {
				$this.lineMap.Add(++$l, $i+1)
			}
		}

		$this.Tokenize()
	}

	Tokenizer() {}

	[string] PeekChars([int]$numChars) {
		if($numChars -lt 0) {
			return $this.InputData[($this.cpos-1-$numChars)..($this.cpos-1)] -join ''
		}
		return $this.InputData[$this.cpos..($this.cpos+$numChars-1)] -join ''
	}

	[char] PeekChar() {
		return $this.InputData[$this.cpos]
	}

	[void] SkipChar() {
		$this.cpos++
	}

	[char] GetChar() {
		return $this.InputData[$this.cpos++]
	}

	[void] UnGetChar() {
		$this.cpos--
	}

	[Token] NewToken([TokenType]$tokenType) {
		return [Token]::new($tokenType, ($this.InputData[$this.tokenStart..($this.cpos-1)] -join ''), $this.tokenStart, ($this.cpos - $this.tokenStart), ($this.lineMap.GetEnumerator().Where({$_.Value -le $this.tokenStart})[0].Name), ($this.tokenStart - $this.lineMap.GetEnumerator().Where({$_.Value -le $this.tokenStart})[0].Value + 1))
	}

	[token] ScanNewLine([char]$c) {
		if($c -eq "`r" -and $this.PeekChar() -eq "`n") {
			$this.SkipChar()
		}
		return $this.NewToken([TokenType]::NewLine)
	}

	[Token] ScanBlockComment([TokenType]$tokenType) {
		$this.SkipChar()
		switch ($tokenType) {
			{$_ -eq [TokenType]::CStyleBlockComment} {
				while(-not ($this.GetChar() -eq '*' -and $this.PeekChar() -eq '/')) {}
			}
			{$_ -eq [TokenType]::PSBlockComment} {
				while(-not ($this.GetChar() -eq '#' -and $this.PeekChar() -eq '>')) {}
			}
		}
		$this.SkipChar()
		return $this.NewToken($tokenType)
	}

	[Token] ScanLineComment([TokenType]$tokenType) {
		while($this.GetChar() -notin 0,"`r", "`n") {}
		$this.UnGetChar()
		return $this.NewToken($tokenType)
	}

	[Token] ScanDirective() {
		while($this.GetChar() -match '[_a-z0-9]') {}
		$this.UnGetChar()
		return $this.NewToken([TokenType]::Directive)
	}

	[Token] ScanStringLiteral() {
		while(1) {
			$c = $this.GetChar()
			if($c -eq "'" -and $this.PeekChar() -eq "'") {
				$this.SkipChar()
				continue
			}
			if($c -eq "``" -and $this.PeekChar() -in "'","``") {
				$this.SkipChar()
				continue
			}
			if($c -eq "'") {
				break
			}
		}
		return $this.NewToken([TokenType]::StringLiteral)
	}

	# Well, this is obviously not expandable yet, so....  add to to-do list
	[Token] ScanStringExpandable() {
		while(1) {
			$c = $this.GetChar()
			if($c -eq '"' -and $this.PeekChar() -eq '"') {
				$this.SkipChar()
				continue
			}
			if($c -eq "``" -and $this.PeekChar() -in '"',"``") {
				$this.SkipChar()
				continue
			}
			if($c -eq '"') {
				break
			}
		}
		return $this.NewToken([TokenType]::StringExpandable)
	}

	# [Token] ScanMnemonic() {
	#     [char]$c = $this.GetChar()
	#     while($c -notmatch '[;\r\n]' -and -not ($c -eq '/' -and $this.PeekChar() -eq '/')) {
	#         $c = $this.GetChar()
	#     }
	#     $this.UnGetChar()
	#     return $this.NewToken([TokenType]::Mnemonic)
	# }

	[Token] ScanIdentifier() {
		while($this.GetChar() -match '[_a-z0-9]') {}
		$this.UnGetChar()
		if($this.PeekChar() -eq ':' -and $this.tokens[-1].Type -eq [TokenType]::Minus) {
			$this.SkipChar()
			return $this.NewToken([TokenType]::PSFunctionParameter)
		}
		if($this.PeekChar() -eq ':') {
			$this.SkipChar()
			return $this.NewToken([TokenType]::Label)
		}
		if(($this.InputData[$this.tokenStart..$this.cpos] -join '') -match '^(ADC|AND|ASL|BCC|BCS|BEQ|BIT|BMI|BNE|BPL|BRK|BVC|BVS|CLC|CLD|CLI|CLV|CMP|CPX|CPY|DEC|DEX|DEY|EOR|INC|INX|INY|JMP|JSR|LDA|LDX|LDY|LSR|NOP|ORA|PHA|PHP|PLA|PLP|ROL|ROR|RTI|RTS|SBC|SEC|SED|SEI|STA|STX|STY|TAX|TAY|TSX|TXA|TXS|TYA)\b' -and $this.tokens[-1].Type -ne [TokenType]::Minus) {
			# return $this.ScanMnemonic()
			return $this.NewToken([TokenType]::Mnemonic)
		}
		return $this.NewToken([TokenType]::Identifier)
	}

	[Token] ScanNumber() {
		if($this.PeekChar() -eq 'x') {
			$this.SkipChar()
			while($this.GetChar() -in $script:CharsHex) {}
			$this.UnGetChar()
			return $this.NewToken([TokenType]::NumericLiteral)
		}
		if($this.PeekChar() -eq 'b') {
			$this.SkipChar()
			while($this.GetChar() -in '0','1') {}
			$this.UnGetChar()
			return $this.NewToken([TokenType]::NumericLiteral)
		}
		if($this.PeekChar() -eq '.') {
			$this.SkipChar()
			if($this.PeekChar() -eq '.') {
				$this.UnGetChar()
				return $this.NewToken([TokenType]::NumericLiteral)
			}
			while($this.GetChar() -in $script:Chars0to9) {}
			$this.UnGetChar()
			return $this.NewToken([TokenType]::NumericLiteral)
		}
		while($this.GetChar() -in $script:Chars0to9) {}
		$this.UnGetChar()
		return $this.NewToken([TokenType]::NumericLiteral)
	}

	[Token] ScanVariable() {
		while($this.GetChar() -in $script:CharsIdentifier) {}
		$this.UnGetChar()
		return $this.NewToken([TokenType]::PSVariable)
	}

	[Token] ScanMember() {
		while($this.GetChar() -in $script:CharsIdentifier) {}
		$this.UnGetChar()
		return $this.NewToken([TokenType]::Member)
	}


	[Token] NextToken() {
		$this.tokenStart = $this.cpos
		[char]$c = $this.GetChar()
		switch($c) {
			'/' {
				switch($this.PeekChar()) {
					'*' {return $this.ScanBlockComment([TokenType]::CStyleBlockComment)}
					'/' {return $this.ScanLineComment([TokenType]::CStyleLineComment)}
				}
			}
			'<' {
				if($this.PeekChar() -eq '#') {
					return $this.ScanBlockComment([TokenType]::PSBlockComment)
				}
				return $this.NewToken([TokenType]::LAngle)
			}
			'#' {
				$i=-1
				while($this.tokens[$i].Type -notin $null, [TokenType]::SemiColon, [TokenType]::NewLine){
					if($this.tokens[$i].Type -eq [TokenType]::Hash) {
						return $this.NewToken([TokenType]::PSLineComment)
					}
					if($this.tokens[$i].Type -eq [TokenType]::Mnemonic) {
						return $this.NewToken([TokenType]::Hash)
					}
					$i--
				}
				return $this.ScanLineComment([TokenType]::PSLineComment)
			}
			'>' {return $this.NewToken([TokenType]::RAngle)}
			'(' {return $this.NewToken([TokenType]::LParen)}
			')' {return $this.NewToken([TokenType]::RParen)}
			'[' {return $this.NewToken([TokenType]::LBracket)}
			']' {return $this.NewToken([TokenType]::RBracket)}
			'{' {return $this.NewToken([TokenType]::LCurly)}
			'}' {return $this.NewToken([TokenType]::RCurly)}
			'+' {return $this.NewToken([TokenType]::Plus)}
			'-' {return $this.NewToken([TokenType]::Minus)}
			'/' {return $this.NewToken([TokenType]::Divide)}
			'*' {return $this.NewToken([TokenType]::Asterisk)}
			'%' {
				$i=-1
				while($this.tokens[$i].Type -notin $null, [TokenType]::SemiColon, [TokenType]::NewLine) {
					if($this.tokens[$i--].Type -in [TokenType]::Mnemonic, [TokenType]::Directive) {
						$k=-1
						while($this.tokens[$k].Type -notin [TokenType]::Mnemonic, [TokenType]::Directive) {
							if($this.tokens[$k].Type -in [TokenType]::Whitespace) {
								$k--
								continue
							}
							if($this.tokens[$k--].Type -in [TokenType]::Hash, [TokenType]::Comma, [TokenType]::Divide, [TokenType]::Equals, [TokenType]::LAngle, [TokenType]::RAngle, [TokenType]::LParen, [TokenType]::Minus, [TokenType]::Modulo, [TokenType]::Plus, [TokenType]::Asterisk) {
								$cnt=0
								while($this.GetChar() -in $script:CharsBin) {$cnt++}
								$this.UnGetChar()
								if($cnt -gt 0 -and $this.PeekChar() -match '\W') {
									return $this.NewToken([TokenType]::NumericLiteral)
								} else {
									# return $this.ScanVariable()
								}
							}
							return $this.NewToken([TokenType]::Modulo)
						}
					}
				}
				return $this.NewToken([TokenType]::Modulo)
			}
			'=' {return $this.NewToken([TokenType]::Equals)}
			',' {return $this.NewToken([TokenType]::Comma)}
			'|' {return $this.NewToken([TokenType]::Pipe)}

			"'" {
				return $this.ScanStringLiteral()
			}
			'"' {
				return $this.ScanStringExpandable()
			}

			{$_ -in " ","`t","`f","`v"} {
				return $this.NewToken([TokenType]::WhiteSpace)
			}
			"`n" {return $this.ScanNewline($c)}
			"`r" {return $this.ScanNewline($c)}
			';' {
				return $this.NewToken([TokenType]::SemiColon)
			}
			'.' {
				if($this.PeekChar() -match '[_a-z]') {
					if($this.tokens[-1].Type -in [TokenType]::WhiteSpace, [TokenType]::NewLine, [TokenType]::SemiColon, $null) {
						return $this.ScanDirective()
					}
					return $this.ScanMember()
				}
				if($this.PeekChar() -eq '.') {
					$this.SkipChar()
					return $this.NewToken([TokenType]::DotDot)
				}
			}
			':' {
				# missing check for ternary <exp> ? <true> : <false>
				$c1 = $this.PeekChar()
				if($c1 -eq '+' -or $c1 -eq '-') {
					while($this.GetChar() -eq $c1) {}
					$this.UnGetChar()
					$ccc = $this.PeekChar()
					if($this.PeekChar() -in ([char[]]'$' + $script:CharsIdentifier)) {
						$this.UnGetChar()
					}
					return $this.NewToken([TokenType]::AnonymousReference)
				}
				if($c1 -eq ':') {
					$this.SkipChar()
					return $this.NewToken([TokenType]::ColonColon)
				}
				return $this.NewToken([TokenType]::AnonymousLabel)
			}
			{$_ -in $script:Chars0to9} {
				return $this.ScanNumber()
			}
			'$' {
				$i=-1
				while($this.tokens[$i].Type -notin $null, [TokenType]::SemiColon, [TokenType]::NewLine){
					if($this.tokens[$i--].Type -in [TokenType]::Mnemonic, [TokenType]::Directive) {
						$cnt=0
						while($this.GetChar() -in $script:CharsHex) {$cnt++}
						$this.UnGetChar()
						if($cnt -gt 0 -and $this.PeekChar() -match '\W') {
							return $this.NewToken([TokenType]::NumericLiteral)
						} else {
							# return $this.ScanVariable()
						}
					}
				}
				return $this.ScanVariable()
			}

			{$_ -in [char[]]($script:Char_ + $script:CharsAtoZ)} {
				return $this.ScanIdentifier()
			}
			default {
				return $this.NewToken([TokenType]::Unknown)
			}
		}
		Write-Host "'$c' at $($this.cpos ) WHAT?! this should not happen."
		return [Token]::new()
	}

	Tokenize() {
		while($this.PeekChar() -ne 0) {
			$this.tokens.Add($this.NextToken())
		}
		$this.tokens.Add([Token]::new([TokenType]::EOF, $null, $this.cpos, 0, $null, $null))
	}
}
