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
	[string]$asmSource
	[string[]]$asmSourceLines
	[string]$psSource
	[byte[]]$binary
	[string]$binaryHash
	[int]$MaxPasses = 300
	[int]$CurrentPass = 0
	[bool]$NoHostOutput
	[SemanticParser]$parser
	[Scope[]]$scopes

	PASM() {
		$this.Init()
	}

	PASM([string]$asmSource, [bool]$NoHostOutput) {
		$this.Init()
		$this.asmSource = $asmSource
		$this.asmSourceLines = $asmSource.Split("`n")
		$this.NoHostOutput = $NoHostOutput
	}

	hidden [void]Init() {
		$this.pc = 0
		$this.loadAddress = 0x0000
		# $this.symbols = [SymbolTable]::new()
		# $this.symbols.AddSymbol("___load_addr", $this.loadAddress)
		#  = [ordered] @{
		# 	____load_addr = @{
		# 		value = $this.loadAddress
		# 		width = 16
		# 		resolved = $true			### Need to find clever way to "actually" resolve this
		# 	}
		# }
		$this.assembly = [System.Collections.ArrayList]@()
	}

	[void]AddLine([UInt16]$addr, [byte[]]$bytes, [System.Management.Automation.InvocationInfo]$invocation) {
		$this.assembly.Add([AssemblyLine]::new($addr, $bytes, $invocation.ScriptLineNumber, $invocation.OffsetInLine, $this.asmSourceLines[$invocation.ScriptLineNumber-1], $invocation.Line.Trim(), $invocation.ScriptName))
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

	[SemanticParser]Parse() {
		$this.parser = [SemanticParser]::new($this.asmSource)
		$this.psSource = $this.parser.outTokens.value -join ''
		# write-host $this.psSource
		$this.scopes = $this.parser.scopeManager.scopes
		$this.symbolManager = $this.parser.symbolManager
		$this.symbolManager.CurrentPass = $this.CurrentPass
		$this.symbolManager.scopes = $this.scopes
		# write-host $this.psSource
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
			$this.pc = 0
			$error.Clear()
			$psError=$null

			try {
				$sb = [ScriptBlock]::Create(($this.psSource | out-string))
			} catch {
				if(-not $this.NoHostOutput) {
					Write-Host " FAILED!"
					Write-Host "Error in parsing generated PowerShell source code!"
					Write-Host $this.psSource
					Write-Host "SymbolTable: $($this.symbolManager.GetSymbolTable() | ft -auto | out-string)"
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
				Invoke-Command -ScriptBlock $sb -ErrorAction Stop -ErrorVariable psError #-NoNewScope
			} catch {
				# Write-Error -Message ("Error in psSource line {0}, column {1}: {2} '{3}' {4}" -f $error[0].InvocationInfo.ScriptLineNumber, $error[0].InvocationInfo.OffsetInLine, $error[0].CategoryInfo.Reason, $error[0].CategoryInfo.TargetName, $error[0].Exception.Message)
				# Write-Error -Message ("Error in psSource line {0}, column {1}: {2} '{3}'" -f $error[0].InvocationInfo.ScriptLineNumber, $error[0].InvocationInfo.OffsetInLine, $error[0].CategoryInfo.Reason, $error[0].CategoryInfo.TargetName) -ErrorAction Stop
				if ($psError) {
					if(-not $this.NoHostOutput) {
						Write-Host " FAILED!"
						Write-Host "Error in executing generated PowerShell source code!"
						Write-Host $this.psSource
						Write-Host "SymbolTable: $($this.symbolManager.GetSymbolTable() | ft -auto | out-string)"
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
			Symbols = $this.symbolManager.GetSymbolTable()
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
			# $sb.AppendFormat("`${0,-4}: {1,-9}- Ln: {2,-3} Col: {3,-3} - {4,-25} - {5}", $a, $sbl.ToString(), $ln, $col, $d, $c)
			$sb.AppendFormat("`${0,-4}: {1,-9}- Ln: {2,-3} Col: {3,-3} - {4}", $a, $sbl.ToString(), $ln, $col, $d)
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
