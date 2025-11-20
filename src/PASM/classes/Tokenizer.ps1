class Tokenizer {
	[InputFileStack]$fileStack
    [System.Collections.Generic.List[char]]$InputData
	[int]$cpos
	[int]$tokenStart
	[System.Collections.Generic.List[Object]]$tokens # Apparently the <T> needs to be Object, if the type is custom - can be of custom type when the object is initialized
	[System.Collections.Generic.Stack[int]]$ScopeStack
	[MultiLevelCounter]$classCounter
	[bool]$sawQuestionMark
	[hashtable]$state
	[hashtable]$PendingDirective

	# [string]$InputData
	[string]$Filename		# Just to keep track of the source filename for error reporting
	[hashtable]$lineMap
	# [System.Collections.Generic.List[Token]]$tokens
	# $tokens

	Tokenizer([string]$InputData, [string]$Filename) {
		[int]$l=1
		$this.lineMap = @{$l = 0}
		$this.InputData = $InputData
		$this.Filename = $Filename
		$this.cpos = 0
		$this.tokenStart = 0
		$this.tokens = [System.Collections.Generic.List[Token]]::new()
		$this.ScopeStack = [System.Collections.Generic.Stack[int]]::new()
		$this.classCounter = [MultiLevelCounter]::new(2)

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

	Tokenizer([InputFileStack]$fileStack) {
		$this.fileStack = $fileStack
		$this.InputData = [System.Collections.Generic.List[char]]::new()
		$this.cpos = 0
		$this.tokenStart = 0
		$this.tokens = [System.Collections.Generic.List[Token]]::new()
		$this.ScopeStack = [System.Collections.Generic.Stack[int]]::new()
		$this.classCounter = [MultiLevelCounter]::new(2)
		$this.sawQuestionMark = $false
		$this.PendingDirective = $null
		$this.state = @{}
		$this.Tokenize()
	}


	Tokenizer() {}

	[void] SetState([string]$key) {
		$this.state[$key] = $true
	}

	[void] UnsetState([string]$key) {
		$this.state[$key] = $false
	}

	[bool] GetState([string]$key) {
		return [bool]$this.state[$key]
	}

	# [string] PeekChars([int]$numChars) {
	# 	if($numChars -lt 0) {
	# 		return $this.InputData[($this.cpos-1-$numChars)..($this.cpos-1)] -join ''
	# 	}
	# 	return $this.InputData[$this.cpos..($this.cpos+$numChars-1)] -join ''
	# }

	# [string] PeekCharsBackUntil([char[]]$c) {
	# 	$cp = 0
	# 	while ($this.InputData[$this.cpos-1- ++$cp] -notin $c -and $this.cpos-1-$cp -ge 0) {}
	# 	return $this.InputData[($this.cpos-1-$cp)..($this.cpos-1)] -join ''
	# }

	# [char] PeekChar() {
	# 	return $this.InputData[$this.cpos]
	# }

	# [void] SkipChar() {
	# 	$this.cpos++
	# }

	# [char] GetChar() {
	# 	return $this.InputData[$this.cpos++]
	# }

	# [void] UnGetChar() {
	# 	$this.cpos--
	# }

	# [string] PeekChars([int]$numChars) {
	# 	# Ensure InputData has enough chars
	# 	while ($this.cpos + $numChars -gt $this.InputData.Count) {
	# 		$ch = $this.FileStack.ReadChar()
	# 		if ($ch -eq -1) { return $null }
	# 		$this.InputData.Add($ch)
	# 	}
	# 	return -join $this.InputData[$this.cpos..([Math]::Min($this.cpos+$numChars-1, $this.InputData.Count-1))]
	# }

	[string] PeekCharsBackUntil([char[]]$c) {
		# Walk backwards from current cpos until one of $c is found
		$pos = $this.cpos - 1
		$sb = [System.Text.StringBuilder]::new()
		while ($pos -ge 0) {
			$ch = $this.InputData[$pos]
			if ($c -contains $ch) { break }
			$sb.Insert(0, $ch) | Out-Null
			$pos--
		}
		return $sb.ToString()
	}

	[char] PeekChar() {
		# Ensure InputData has at least one char
		if ($this.cpos -ge $this.InputData.Count) {
			$ch = $this.FileStack.ReadChar()
			if ($ch -eq 0) { return 0 }   # EOF sentinel
			$this.InputData.Add($ch)
		}
		return $this.InputData[$this.cpos] # same index, no increment
	}

	[void] SkipChar() {
		[void]$this.GetChar()
	}

	[char] GetChar() {
		# Ensure InputData has at least one char
		if ($this.cpos -ge $this.InputData.Count) {
			$ch = $this.FileStack.ReadChar()
			if ($ch -eq 0) { return 0 }
			$this.InputData.Add($ch)
		}
		return $this.InputData[$this.cpos++]
	}

	[void] UnGetChar() {
		if ($this.cpos -gt 0) {
			$this.cpos--
		}
	}

	# [Token] NewToken([TokenType]$tokenType) {
	# 	return [Token]::new($tokenType, ($this.InputData[$this.tokenStart..($this.cpos-1)] -join ''), $this.tokenStart, ($this.cpos - $this.tokenStart), ($this.lineMap.GetEnumerator().Where({$_.Value -le $this.tokenStart})[0].Name), ($this.tokenStart - $this.lineMap.GetEnumerator().Where({$_.Value -le $this.tokenStart})[0].Value + 1), $this.Filename)
	# }

	[Token] NewToken([TokenType]$tokenType) {
		$ctx = $this.FileStack.CurrentContext()
		$lexeme = ($this.InputData[$this.tokenStart..($this.cpos-1)] -join '')

		$token = [Token]::new(
			$tokenType,
			$lexeme,
			$this.tokenStart,
			($this.cpos - $this.tokenStart),
			$ctx.Line,
			$ctx.Column,
			$ctx.File
		)

		# $this.tokens.Add($token)

		return $token
	}

	[token] ScanNewLine([char]$c) {
		if($c -eq "`r" -and $this.PeekChar() -eq "`n") {
			$this.SkipChar()
		}
		$this.HandlePendingDirective()
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

	[Token] ScanDirective($str) {
		switch -regex ($str) {
			'^\.include$'		{ $this.PendingDirective = @{Directive=$str; Index=$this.tokens.Count }}
			'^\.incdir$'		{ $this.PendingDirective = @{Directive=$str; Index=$this.tokens.Count }}
			'^\.includeonce$'	{ $this.FileStack.MarkCurrentFileIncludeOnce() }
		}
		return $this.NewToken([TokenType]::Directive)
	}

	[void] HandlePendingDirective() {
		if ($this.PendingDirective) {
			switch ($this.PendingDirective.Directive) {
				'.include' {
					for ($i = $this.PendingDirective.Index+1; $i -lt $this.tokens.Count; $i++) {
						if ($this.tokens[$i].Type -in [TokenType]::StringLiteral, [TokenType]::StringExpandable) {
							$file = & { $ExecutionContext.InvokeCommand.ExpandString($this.tokens[$i].Value.Trim('"''')) }
							if ($file -ne '') {
								$this.FileStack.PushFile($file)
							}
						}
					}
					$this.PendingDirective = $null
					break
				}
				'.incdir' {
					for ($i = $this.PendingDirective.Index+1; $i -lt $this.tokens.Count; $i++) {
						if ($this.tokens[$i].Type -in [TokenType]::StringLiteral, [TokenType]::StringExpandable) {
							$file = & { $ExecutionContext.InvokeCommand.ExpandString($this.tokens[$i].Value.Trim('"''')) }
							if ($file -ne '') {
								$this.FileStack.AddIncludeDir($file)
							}
						}
					}
					$this.PendingDirective = $null
					break
				}
			}
		}
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
		while($this.GetChar() -match '^[_a-z0-9]') {}
		$this.UnGetChar()
		if($this.PeekChar() -eq ':' -and $this.tokens[-1].Type -eq [TokenType]::Minus) {
			$this.SkipChar()
			return $this.NewToken([TokenType]::PSFunctionParameter)
		}
		if($this.PeekChar() -eq ':') {
			$this.SkipChar()
			return $this.NewToken([TokenType]::Label)
		}
		if ($this.classCounter.Counters[0] -gt 0 -and $this.classCounter.Counters[1] -eq 1) {
			# We're in a class, only methods and properties allowed here.. not sure how to handle props yet ;-)
			# This is necessary to avoid macros being misinterpreted as methods, when used in classes
			# and classes can be nested, that's why the MultiLevelCounter class is used - 0: class level, 1: scope level - and methods only exist at scope level 1
			return $this.NewToken([TokenType]::PSClassMethod)
		}
		$str = $this.InputData[$this.tokenStart..($this.cpos-1)] -join ''
		if(($str) -in $script:PSKeywords) {
			return $this.ScanPSKeyword()
		}
		if(($str) -in $script:PASMFunctions) {
			return $this.ScanDirective($str)
		}
		if(($this.InputData[$this.tokenStart..$this.cpos] -join '') -match '^(ADC|AND|ASL|BCC|BCS|BEQ|BIT|BMI|BNE|BPL|BRK|BVC|BVS|CLC|CLD|CLI|CLV|CMP|CPX|CPY|DEC|DEX|DEY|EOR|INC|INX|INY|JMP|JSR|LDA|LDX|LDY|LSR|NOP|ORA|PHA|PHP|PLA|PLP|ROL|ROR|RTI|RTS|SBC|SEC|SED|SEI|STA|STX|STY|TAX|TAY|TSX|TXA|TXS|TYA)\b' -and $this.tokens[-1].Type -ne [TokenType]::Minus) {
			# return $this.ScanMnemonic()
			return $this.NewToken([TokenType]::Mnemonic)
		}
		return $this.NewToken([TokenType]::Identifier)
	}

	[Token] ScanPSKeyword() {
		switch(($this.InputData[$this.tokenStart..($this.cpos-1)] -join '')) {
			"class" { $this.classCounter.Inc(0) }
		}
		return $this.NewToken([TokenType]::PSKeyword)
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
		if ($this.GetChar() -eq ':') {
			$c = $this.PeekChar()
			if ($c -in '+','-') {
				while($this.GetChar() -eq $c) {}
				$this.UnGetChar()
				if($this.PeekChar() -in ([char[]]'$' + $script:CharsIdentifier)) {
					$this.UnGetChar()
				}
			}
		} else {
			while($this.GetChar() -in $script:CharsIdentifier) {}
			$this.UnGetChar()
		}
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
						return $this.ScanLineComment([TokenType]::PSLineComment)
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
			'{' {
					if ($this.classCounter.Counters[0] -gt 0) {
						$this.classCounter.Inc(1)
					}
					return $this.NewToken([TokenType]::LCurly)
				}
			'}' {
					if ($this.classCounter.Counters[0] -gt 0) {
						$this.classCounter.Dec(1)
						if ($this.classCounter.Counters[1] -eq 0) {
							$this.classCounter.Dec(0)
						}
					}
					return $this.NewToken([TokenType]::RCurly)
				}
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
								if($cnt -gt 0 -and $this.PeekChar() -match '^\W') {
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
				$this.HandlePendingDirective()
				return $this.NewToken([TokenType]::SemiColon)
			}
			'.' {
				if($this.PeekChar() -match '^[_a-z:]') {
					if($this.tokens[-1].Type -in [TokenType]::WhiteSpace, [TokenType]::NewLine, [TokenType]::SemiColon, [TokenType]::LCurly, [TokenType]::LParen, $null) {
						return $this.ScanIdentifier() # Identifiers can start with a . and not all directives start with a . so ScanIdentifier is used to figure out if it's a directive or not
					}
					return $this.ScanMember()
				}
				if($this.PeekChar() -eq '.') {
					$this.SkipChar()
					return $this.NewToken([TokenType]::DotDot)
				}
				return $this.NewToken([TokenType]::Dot)
			}
			':' {
				if ($this.sawQuestionMark) {
					$this.sawQuestionMark = $false
					return $this.NewToken([TokenType]::TernaryColon)
				}
				$c1 = $this.PeekChar()
				if($c1 -eq '+' -or $c1 -eq '-') {
					while($this.GetChar() -eq $c1) {}
					$this.UnGetChar()
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
						if($cnt -gt 0 -and $this.PeekChar() -match '^\W') {
							return $this.NewToken([TokenType]::NumericLiteral)
						} else {
							# return $this.ScanVariable()
						}
					}
				}
				return $this.ScanVariable()
			}
			'?' {
				if ($this.PeekChar() -eq '?') {
					$this.SkipChar()
					return $this.NewToken([TokenType]::NullCoalesce)
				}
				if ($this.PeekChar() -eq '.') {
					$this.SkipChar()
					return $this.NewToken([TokenType]::NullConditionalProperty)
				}
				if ($this.PeekChar() -eq '[') {
					$this.SkipChar()
					return $this.NewToken([TokenType]::NullConditionalIndex)
				}
				$this.sawQuestionMark = $true
				return $this.NewToken([TokenType]::QuestionMark)
			}

			{$_ -in [char[]]($script:Char_ + $script:CharsAtoZ)} {
				return $this.ScanIdentifier()
			}
			default {
				return $this.NewToken([TokenType]::Unknown)
			}
		}
		Write-Host "'$c' at $($this.cpos ) WHAT?! this should not happen."
		return $this.NewToken([TokenType]::Error)
	}

	Tokenize() {
		while($this.PeekChar() -ne 0) {
			$this.tokens.Add($this.NextToken())
		}
		$this.tokenStart = $this.cpos++
		$this.tokens.Add($this.NewToken([TokenType]::EOF))
	}
}
