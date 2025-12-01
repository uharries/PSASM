function .inst {
	[PASM()] param (
		[Parameter(Mandatory=$true)]
		[Alias("mn")]
		# [ValidateScript({[MOS6502]::OpCodes.$_}, ErrorMessage="Unknown mnemonic: '{0}'")]
		[string]$Mnemonic,

		[Parameter(Mandatory=$true)]
		[Alias("am")]
		# [ValidateScript({[MOS6502]::OpCodes.$Mnemonic.$_}, ErrorMessage="Unknown addressing mode '{0}' for mnemonic")]
		[string]$AddressingMode,

		[Parameter(Mandatory=$false)]
		[Alias("op")]
		[object]$Operand,

		[string]$InvocationFile,
		[int]$InvocationLine
	)

	# maybe for another day, when I have a need to process symbols stored in variables at runtime, or whatever...
	# if ($Operand -is [string]) {
	# 	if ($pasm.symbols.ContainsKey($Operand)) {
	# 		if ($false -eq $pasm.symbols[$Operand].resolved) {
	# 			$Operand = [UInt16]0x0000
	# 		}
	# 		if ($true -eq $pasm.symbols[$Operand].resolved) {
	# 			$Operand = [UInt16]($pasm.symbols[$Operand].value)
	# 		}
	# 	} else {
	# 		Write-Error "Symbol not found: '$Operand'"
	# 	}
	# }

	if($Operand -lt 256) {
		switch ($AddressingMode) {
			'Absolute' {
				if ([MOS6502]::OpCodes.$Mnemonic.ZeroPage) {
					$AddressingMode = "ZeroPage"
				}
			}
			'AbsoluteIndexedX' {
				if ([MOS6502]::OpCodes.$Mnemonic.ZeroPageIndexedX) {
					$Addressingmode = 'ZeroPageIndexedX'
				}
			}
			'AbsoluteIndexedY' {
				if ([MOS6502]::OpCodes.$Mnemonic.ZeroPageIndexedY) {
					$Addressingmode = 'ZeroPageIndexedY'
				}
			}
		}
	}

	if ($AddressingMode -match 'Relative') {
		$Operand = [byte](($Operand - $pasm.pc - 2) -band 255)
	}

	if ([MOS6502]::OperandSize.$AddressingMode -eq 16) {
		$pasm.OpAdd([MOS6502]::OpCodes.$Mnemonic.$AddressingMode, ($Operand -band 0xffff), $InvocationFile, $InvocationLine)
	}
	if ([MOS6502]::OperandSize.$AddressingMode -eq 8) {
		$pasm.OpAdd([MOS6502]::OpCodes.$Mnemonic.$AddressingMode, [byte]($Operand -band 0xff), $InvocationFile, $InvocationLine)
	}
	if ([MOS6502]::OperandSize.$AddressingMode -eq 0) {
		$pasm.OpAdd([MOS6502]::OpCodes.$Mnemonic.$AddressingMode, $InvocationFile, $InvocationLine)
	}
}
