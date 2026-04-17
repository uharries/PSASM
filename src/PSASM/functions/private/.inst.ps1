function .inst {
	[PSASM()] param (
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

	if (-not [MOS6502]::opcodes.$Mnemonic.ContainsKey($AddressingMode)) {
		throw "Unknown addressing mode '$AddressingMode' for mnemonic '$Mnemonic' at line $InvocationLine in file '$InvocationFile'."
	}

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
		$Operand = [byte](($Operand - $psasm.Segments.Current.PC - 2) -band 255)
	}

	if ([MOS6502]::OperandSize.$AddressingMode -eq 16) {
		$psasm.OpAdd([MOS6502]::OpCodes.$Mnemonic.$AddressingMode, ($Operand -band 0xffff), $InvocationFile, $InvocationLine)
	}
	if ([MOS6502]::OperandSize.$AddressingMode -eq 8) {
		$psasm.OpAdd([MOS6502]::OpCodes.$Mnemonic.$AddressingMode, [byte]($Operand -band 0xff), $InvocationFile, $InvocationLine)
	}
	if ([MOS6502]::OperandSize.$AddressingMode -eq 0) {
		$psasm.OpAdd([MOS6502]::OpCodes.$Mnemonic.$AddressingMode, $InvocationFile, $InvocationLine)
	}
}
