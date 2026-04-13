class PASM {
	[UInt16]$loadAddress
	[SymbolManager]$symbolManager
	[System.Collections.ArrayList]$assembly
	[string]$psSource
	[byte[]]$binary
	[string]$binaryHash
	[int]$MaxPasses = 25
	[int]$CurrentPass = 0
	[bool]$NoHostOutput
	[SemanticParser]$parser
	[Scope[]]$scopes
	[hashtable]$Macros = [ordered] @{0 = [ordered] @{ BRA = {param($addr)jmp $addr}}} # [ScopeID][Name] = [ScriptBlock]
	[InputFileStack]$FileStack
	[HashTable]$SourceLines
	[SegmentManager]$Segments


	PASM() {
		$this.Init()
	}


	hidden [void]Init() {
		$this.loadAddress = 0x0000
		$this.assembly = [System.Collections.ArrayList]@()
		$this.FileStack = [InputFileStack]::new()
		$this.SourceLines = @{}
		$this.Segments = [SegmentManager]::new()
	}


	[void] BuildSourceLines() {
		foreach ($ctx in $this.FileStack.AllContexts) {
			$key = $ctx.FilePath  # already normalized full path

			if (-not $this.SourceLines.ContainsKey($key)) {
				# Store the lines only once, ignore duplicates
				$this.SourceLines[$key] = $ctx.Content `
					-replace "`r`n", "`n" `
					-replace "`r", "`n" `
					-replace ([char]0x2028), "`n" `
					-replace ([char]0x2029), "`n" `
					-split("`n")
			}
		}
	}


	[void] LoadFile([string]$filePath) {
		$this.FileStack.PushFile($filePath)
	}


	[void] LoadVirtualFile([string]$virtualName, [string]$sourceCode) {
		$this.FileStack.PushVirtualFile($virtualName, $sourceCode)
	}


	[void]AddLine([byte[]]$bytes, [string]$invocationFile, [int]$invocationLine) {

		# Write-Host "`$invocation.Line: $($invocationLine)"
		# Write-Host "File: $($invocationFile)"
		# Write-Host "Line: $($invocationLine)"
		# Write-Host "Source: $(($map = $this.parser.LineMap[$invocation.Line]) ? $this.SourceLines[$map.File][$map.Line - 1] : "<nullllll>")"
		# Write-Host "Source: $($this.SourceLines[$invocationFile]?[$invocationLine - 1] ?? "<nullllll>")"

		$this.assembly.Add([AssemblyLine]::new(
			$this.Segments.Current.Name,
			$this.Segments.Current.PC,
			$bytes,
			$invocationLine,
			0,
			$this.SourceLines[$invocationFile]?[$invocationLine - 1] ?? "<null>",
			"<no psSourceLine>",
			$invocationFile
		))
		$this.Segments.Emit($bytes)
	}


	[void]OpAdd([byte]$OpCode, [string]$invocationFile, [int]$invocationLine) {
		$this.AddLine(@($OpCode), $invocationFile, $invocationLine)
	}


	[void]OpAdd([byte]$OpCode, [byte]$Operand, [string]$invocationFile, [int]$invocationLine) {
		$this.AddLine(@($OpCode,$Operand), $invocationFile, $invocationLine)
	}


	[void]OpAdd([byte]$OpCode, [UInt16]$Operand, [string]$invocationFile, [int]$invocationLine) {
		$this.AddLine(@($OpCode,(_loByte $Operand),(_hiByte $Operand)), $invocationFile, $invocationLine)
	}


	[void]DataAdd([byte[]]$data, [string]$invocationFile, [int]$invocationLine) {
		$this.AddLine($data, $invocationFile, $invocationLine)
	}


	[void]DataAdd([UInt16[]]$data, [string]$invocationFile, [int]$invocationLine) {
		$this.AddLine([byte[]]($data | ForEach-Object{_loByte $_;_hiByte $_}), $invocationFile, $invocationLine)
	}


	[void]Parse() {
		$this.parser = [SemanticParser]::new($this.FileStack)
		$this.BuildSourceLines()
		$this.FileStack.Dispose()
		$this.psSource = $this.parser.outTokens.value -join ''
		$this.scopes = $this.parser.scopeManager.scopes
		$this.symbolManager = $this.parser.symbolManager
		$this.symbolManager.CurrentPass = $this.CurrentPass
		$this.symbolManager.scopes = $this.scopes
	}


	[void]Assemble() {
		$success=$false
		$bin=[System.Collections.Generic.List[byte]]::new()

		for ($i=1; $i -le $this.MaxPasses -and $success -ne $true; $i++) {
			$this.CurrentPass = $i
			$this.symbolManager.CurrentPass = $i
			if(-not $this.NoHostOutput) {
				Write-Host "Pass $($i)..." -NoNewline
			}
			$this.assembly.Clear()
			$this.Segments.Reset()
			$error.Clear()
			$psError=$null

			try {
				$sb = [ScriptBlock]::Create(($this.psSource | out-string))
			} catch {
				if(-not $this.NoHostOutput) {
					Write-Host " FAILED!"
					# Write-Host "Error in parsing generated PowerShell source code!"
				}
				throw
			}

			try {
				Invoke-Command -ScriptBlock $sb -ErrorAction Stop -ErrorVariable psError #-NoNewScope
			} catch {
				if ($psError) {
					if(-not $this.NoHostOutput) {
						Write-Host " FAILED!"
						# Write-Host "Error in executing generated PowerShell source code!"
					}
				}
				throw
			}

			### Solve segment layout
			$this.Segments.SolveLayout()

			### Build binary - BuildBinary() must be run to populate Segments.LowestAddress
			$binaryData = $this.Segments.BuildBinary()
			$this.loadAddress = $this.Segments.LowestAddress
			$bin.Clear()
			$bin.Add(([byte]($this.loadAddress -band 255)))
			$bin.Add(([byte](($this.loadAddress -shr 8) -band 255)))
			$bin.AddRange($binaryData)

			$oldHash = $this.binaryHash
			$this.binaryHash = [System.BitConverter]::ToString([System.Security.Cryptography.SHA256CryptoServiceProvider]::new().ComputeHash($bin)) -replace '-',''
			if(-not $this.NoHostOutput) {
				# Write-Host (" OK! - Hash: {0}" -f $this.binaryHash)
				Write-Host " OK!"
			}
			if ($this.binaryHash -eq $oldHash) {
				# if ($this.symbolManager.Symbols.Values.Values.Resolved -contains $false) {
					# $s = "'" + (($this.symbolManager.Symbols.Values.Values.Where({!$_.Resolved})).Name -join "', '") + "'"
					# throw [System.Exception]::new("Unable to resolve symbols: $s")
					# Write-Warning -Message "Unresolved symbols defined: $s"
					# break
				# }
				$this.binary = $bin.ToArray()
				$success = $true
			}
		}

		if (!$success) {
			throw [System.Exception]::new("Maximum number of passes exceeded: $($this.MaxPasses)")
		}
	}


	[AssemblyResult]ToResult() {
		$info = [AssemblyResult]::new()
		$info.LoadAddress  = $this.loadAddress
		$info.Scopes       = $this.scopes
		$info.Symbols      = $this.symbolManager?.GetSymbolTable()
		$info.SymbolsFull  = $this.symbolManager?.GetFullSymbolTable()
		$info.PSSource     = $this.PSSource
		$info.Segments     = $this.Segments?.Segments
		$info.SegmentInfo  = $this.Segments?.DumpSegments()
		$info.Assembly     = $this.Assembly
		$info.AssemblyList = $this.ListAssembly()
		$info.Binary       = $this.Binary
		$info.BinaryList   = $this.HexDump()
		$info.BinaryHash   = $this.BinaryHash
		$info.Tokens	   = $this.parser?.inTokens
		# ... anything else $pasm knows about
		return $info
	}


	###
	### Assembly Lister
	###
	[string]ListAssembly() {
		$sb = [System.Text.StringBuilder]::new(1024)
		$sbl = [System.Text.StringBuilder]::new(64)
		$currentDir = $this.FileStack.AllContexts[0].FilePath
		if (Test-Path $currentDir) { $currentDir = Split-Path $currentDir -Parent } else { $currentDir = (Get-Location).ProviderPath }
		$currentFile = ""
		$displayFile = $currentFile
		for ($lin=0;$lin -lt $this.assembly.count; $lin++) {
			if ($this.assembly[$lin].fileName -ne $currentFile) {
				$currentFile = $this.assembly[$lin].fileName
				$displayFile = if (Test-Path $currentFile) { Resolve-Path $currentFile -Relative -RelativeBasePath $currentDir } else { $currentFile }
				# $sb.AppendFormat("File: {0}", $displayFile)
				# $sb.AppendLine()
			}
			$a = ("{0:x4}" -f $this.assembly[$lin].addr)
			$sbl.Clear()
			for ($i=1; $i -le $this.assembly[$lin].bytes.Count; $i++) {
				$sbl.AppendFormat("{0:x2} ", $this.assembly[$lin].bytes[$i-1])
				if ($i % 16 -eq 0 -and $i+1 -le $this.assembly[$lin].bytes.Count) {
					$sbl.Append("`n       ")
				}
			}
			$ln = $this.assembly[$lin].lineNumber
			$col = $this.assembly[$lin].charPosition
			$c = ("{0}" -f $this.assembly[$lin].psLineText.Trim())
			$d = ("{0}" -f $this.assembly[$lin].asmLineText.Trim())
			# $sb.AppendFormat("`${0,-4}: {1,-9}- Ln: {2,-3} Col: {3,-3} - {4,-25} - {5}", $a, $sbl.ToString(), $ln, $col, $d, $c)
			# $sb.AppendFormat("`${0,-4}: {1,-9}- Ln: {2,-3} Col: {3,-3} - {4}", $a, $sbl.ToString(), $ln, $col, $d)
			$sb.AppendFormat("`${0,-4}: {1,-9}- File:{4} Ln: {2,-4} - {3}", $a, $sbl.ToString(), $ln, $d, $displayFile)
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
