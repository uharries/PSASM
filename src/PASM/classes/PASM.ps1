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
	[SymbolManager]$symbolManager
	[System.Collections.ArrayList]$assembly
	[string]$psSource
	[byte[]]$binary
	[string]$binaryHash
	[int]$MaxPasses = 300
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
		# $this.pc = 0
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

	[SemanticParser]Parse() {
		# $this.SourceFiles | ft -auto | out-string | write-host
		$this.parser = [SemanticParser]::new($this.FileStack)
		$this.BuildSourceLines()
		$this.FileStack.Dispose()
		$this.psSource = $this.parser.outTokens.value -join ''
		# write-host $this.psSource
		$this.scopes = $this.parser.scopeManager.scopes
		$this.symbolManager = $this.parser.symbolManager
		$this.symbolManager.CurrentPass = $this.CurrentPass
		$this.symbolManager.scopes = $this.scopes
		# write-host $this.psSource
		# $this.Macros | ft -auto | out-string | write-host
		return $this.parser
	}

	[AssemblerInformation]Assemble() {
		$success=$false
		$bin=[System.Collections.Generic.List[byte]]::new()

		for ($i=1; $i -le $this.MaxPasses -and $success -ne $true; $i++) {
			$this.CurrentPass = $i
			$this.symbolManager.CurrentPass = $i
			if(-not $this.NoHostOutput) {
				# Write-Progress -Activity "Assembly" -Status "Pass $($i)" -PercentComplete 0
				Write-Host "Pass $($i)..." -NoNewline
			}
			$this.assembly.Clear()
			# $this.Segments.ResolveStartAfter()
			$this.Segments.Reset()
			$error.Clear()
			$psError=$null

			try {
				$sb = [ScriptBlock]::Create(($this.psSource | out-string))
			} catch {
				$_.Exception.Data["TOKENS"] = $this.parser.inTokens
				if(-not $this.NoHostOutput) {
					Write-Host " FAILED!"
					Write-Host "Error in parsing generated PowerShell source code!"
					Write-Host $this.psSource
					Write-Host "Scopes: $($this.symbolManager.Scopes | ft -auto | out-string)"
					Write-Host "SymbolTable: $($this.symbolManager.GetFullSymbolTable() | ft -auto | out-string)"
					Write-Host "Look at `$Error[0].Exception.Data['TOKENS'] for the tokens"
				}
				throw
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
				Invoke-Command -ScriptBlock $sb -ErrorAction Stop -ErrorVariable psError #-NoNewScope
			} catch {
				# Write-Error -Message ("Error in psSource line {0}, column {1}: {2} '{3}' {4}" -f $error[0].InvocationInfo.ScriptLineNumber, $error[0].InvocationInfo.OffsetInLine, $error[0].CategoryInfo.Reason, $error[0].CategoryInfo.TargetName, $error[0].Exception.Message)
				# Write-Error -Message ("Error in psSource line {0}, column {1}: {2} '{3}'" -f $error[0].InvocationInfo.ScriptLineNumber, $error[0].InvocationInfo.OffsetInLine, $error[0].CategoryInfo.Reason, $error[0].CategoryInfo.TargetName) -ErrorAction Stop
				if ($psError) {
					if(-not $this.NoHostOutput) {
						Write-Host " FAILED!"
						Write-Host "Error in executing generated PowerShell source code!"
						Write-Host $this.psSource
						Write-Host "Scopes: $($this.symbolManager.Scopes | ft -auto | out-string)"
						Write-Host "SymbolTable: $($this.symbolManager.GetFullSymbolTable() | ft -auto | out-string)"
					}
					throw $_
					# throw [System.Exception]::new(("Error in psSource line {0}, column {1}: {2} '{3}'" -f $psError[0].InvocationInfo.ScriptLineNumber, $psError[0].InvocationInfo.OffsetInLine, $psError[0].CategoryInfo.Reason, $psError[0].CategoryInfo.TargetName))
				} else {
					throw $_
				}
			}
			# not quite sure what to do with errors and the $error object here yet...

			# $this.assembly = @($this.assembly | Sort-Object addr)
			### Solve segment layout
			$this.Segments.SolveLayout()

			# $this.Segments.Segments.Values | sort realStart | ft * -auto | out-string | write-host

			### Build binary - BuildBinary() must be run to populate Segments.LowestAddress
			$binaryData = $this.Segments.BuildBinary()
			$this.loadAddress = $this.Segments.LowestAddress
			$bin.Clear()
			$bin.Add(([byte]($this.loadAddress -band 255)))
			$bin.Add(([byte](($this.loadAddress -shr 8) -band 255)))
			$bin.AddRange($binaryData)
			# $addrCnt = $this.loadAddress
			# foreach ($l in $this.assembly) {
			# 	if($l.addr - $addrCnt -gt 0) {
			# 		# Fill out empty space in binary - 0x00 should be a configurable fillbyte var...
			# 		$bin.AddRange([byte[]]@(0x00) * ($l.addr - $addrCnt))
			# 	}
			# 	$bin.AddRange($l.bytes)
			# 	$addrCnt = $l.addr + $l.bytes.count
			# }

			$oldHash = $this.binaryHash
			$this.binaryHash = [System.BitConverter]::ToString([System.Security.Cryptography.SHA256CryptoServiceProvider]::new().ComputeHash($bin)) -replace '-',''
			if(-not $this.NoHostOutput) {
				# Write-Progress -Activity "Assembly" -Status "Pass $($i)" -PercentComplete (100 / $this.MaxPasses * $i)
				Write-Host (" OK! - Hash: {0}" -f $this.binaryHash)
			}
			if ($this.binaryHash -eq $oldHash) {
				# if ($this.symbolManager.Symbols.Values.Values.Resolved -contains $false) {
					# $s = "'" + (($this.symbolManager.Symbols.Values.Values.Where({!$_.Resolved})).Name -join "', '") + "'"
					# throw [System.Exception]::new("Unable to resolve symbols: $s")
					# Write-Warning -Message "Unresolved symbols defined: $s"
					# break
				# }
				# $this.Segments.ValidateSegments() # Throws if overlaps or overflows detected
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
			Scopes = $this.scopes
			# Symbols = $this.symbolManager.GetFullSymbolTable()
			Symbols = $this.symbolManager.GetSymbolTable()
			Segments = $this.Segments.Segments
			PSSource = $this.psSource | Out-String
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
