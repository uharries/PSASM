class MOS6502 {
	# $c=Import-Csv .\MOS6502OpCodes.csv
	#
	# To update the Sort Order: $c | %{$o=$_; switch ($o.AddressingMode) { "Implied" { $o.AMSortOrder = 1; }; "Immediate" {$o.AMSortOrder =2;}; "Absolute" {$o.AMSortOrder =3;}; "AbsoluteIndexedX" {$o.AMSortOrder =4;}; "AbsoluteIndexedY" {$o.AMSortOrder =5;}; "ZeroPage" {$o.AMSortOrder =6;}; "ZeroPageIndexedX" {$o.AMSortOrder =7;}; "ZeroPageIndexedY" {$o.AMSortOrder =8;}; "IndexedXIndirect" {$o.AMSortOrder =9;}; "IndirectIndexedY" {$o.AMSortOrder =10;}; "IndirectAbsolute" {$o.AMSortOrder =11;}; "Relative" {$o.AMSortOrder = 12;}; }
	# To generate below hashtables: $c | ?{$_.Illegal -eq $false} | sort Mnemonic -Unique | %{$mne = $_.Mnemonic; Write-Host "$mne = @{"; $c | ?{$_.Illegal -eq $false -and $_.Mnemonic -eq $mne} | sort AMSortOrder | %{ Write-Host ("    {0,-16} = 0x{1}" -f $_.AddressingMode, $_.OpCode)}; Write-Host "}"}
	#
	static $OpCodes = [ordered] @{
		ADC = @{
			Immediate        = 0x69
			Absolute         = 0x6D
			AbsoluteIndexedX = 0x7D
			AbsoluteIndexedY = 0x79
			ZeroPage         = 0x65
			ZeroPageIndexedX = 0x75
			IndexedXIndirect = 0x61
			IndirectIndexedY = 0x71
		}
		AND = @{
			Immediate        = 0x29
			Absolute         = 0x2D
			AbsoluteIndexedX = 0x3D
			AbsoluteIndexedY = 0x39
			ZeroPage         = 0x25
			ZeroPageIndexedX = 0x35
			IndexedXIndirect = 0x21
			IndirectIndexedY = 0x31
		}
		ASL = @{
			Implied          = 0x0A
			Absolute         = 0x0E
			AbsoluteIndexedX = 0x1E
			ZeroPage         = 0x06
			ZeroPageIndexedX = 0x16
		}
		BCC = @{
			Relative         = 0x90
		}
		BCS = @{
			Relative         = 0xB0
		}
		BEQ = @{
			Relative         = 0xF0
		}
		BIT = @{
			Absolute         = 0x2C
			ZeroPage         = 0x24
		}
		BMI = @{
			Relative         = 0x30
		}
		BNE = @{
			Relative         = 0xD0
		}
		BPL = @{
			Relative         = 0x10
		}
		BRK = @{
			Implied          = 0x00
		}
		BVC = @{
			Relative         = 0x50
		}
		BVS = @{
			Relative         = 0x70
		}
		CLC = @{
			Implied          = 0x18
		}
		CLD = @{
			Implied          = 0xD8
		}
		CLI = @{
			Implied          = 0x58
		}
		CLV = @{
			Implied          = 0xB8
		}
		CMP = @{
			Immediate        = 0xC9
			Absolute         = 0xCD
			AbsoluteIndexedX = 0xDD
			AbsoluteIndexedY = 0xD9
			ZeroPage         = 0xC5
			ZeroPageIndexedX = 0xD5
			IndexedXIndirect = 0xC1
			IndirectIndexedY = 0xD1
		}
		CPX = @{
			Immediate        = 0xE0
			Absolute         = 0xEC
			ZeroPage         = 0xE4
		}
		CPY = @{
			Immediate        = 0xC0
			Absolute         = 0xCC
			ZeroPage         = 0xC4
		}
		DEC = @{
			Absolute         = 0xCE
			AbsoluteIndexedX = 0xDE
			ZeroPage         = 0xC6
			ZeroPageIndexedX = 0xD6
		}
		DEX = @{
			Implied          = 0xCA
		}
		DEY = @{
			Implied          = 0x88
		}
		EOR = @{
			Immediate        = 0x49
			Absolute         = 0x4D
			AbsoluteIndexedX = 0x5D
			AbsoluteIndexedY = 0x59
			ZeroPage         = 0x45
			ZeroPageIndexedX = 0x55
			IndexedXIndirect = 0x41
			IndirectIndexedY = 0x51
		}
		INC = @{
			Absolute         = 0xEE
			AbsoluteIndexedX = 0xFE
			ZeroPage         = 0xE6
			ZeroPageIndexedX = 0xF6
		}
		INX = @{
			Implied          = 0xE8
		}
		INY = @{
			Implied          = 0xC8
		}
		JMP = @{
			Absolute         = 0x4C
			IndirectAbsolute = 0x6C
		}
		JSR = @{
			Absolute         = 0x20
		}
		LDA = @{
			Immediate        = 0xA9
			Absolute         = 0xAD
			AbsoluteIndexedX = 0xBD
			AbsoluteIndexedY = 0xB9
			ZeroPage         = 0xA5
			ZeroPageIndexedX = 0xB5
			IndexedXIndirect = 0xA1
			IndirectIndexedY = 0xB1
		}
		LDX = @{
			Immediate        = 0xA2
			Absolute         = 0xAE
			AbsoluteIndexedY = 0xBE
			ZeroPage         = 0xA6
			ZeroPageIndexedY = 0xB6
		}
		LDY = @{
			Immediate        = 0xA0
			Absolute         = 0xAC
			AbsoluteIndexedX = 0xBC
			ZeroPage         = 0xA4
			ZeroPageIndexedX = 0xB4
		}
		LSR = @{
			Implied          = 0x4A
			Absolute         = 0x4E
			AbsoluteIndexedX = 0x5E
			ZeroPage         = 0x46
			ZeroPageIndexedX = 0x56
		}
		NOP = @{
			Implied          = 0xEA
		}
		ORA = @{
			Immediate        = 0x09
			Absolute         = 0x0D
			AbsoluteIndexedX = 0x1D
			AbsoluteIndexedY = 0x19
			ZeroPage         = 0x05
			ZeroPageIndexedX = 0x15
			IndexedXIndirect = 0x01
			IndirectIndexedY = 0x11
		}
		PHA = @{
			Implied          = 0x48
		}
		PHP = @{
			Implied          = 0x08
		}
		PLA = @{
			Implied          = 0x68
		}
		PLP = @{
			Implied          = 0x28
		}
		ROL = @{
			Implied          = 0x2A
			Absolute         = 0x2E
			AbsoluteIndexedX = 0x3E
			ZeroPage         = 0x26
			ZeroPageIndexedX = 0x36
		}
		ROR = @{
			Implied          = 0x6A
			Absolute         = 0x6E
			AbsoluteIndexedX = 0x7E
			ZeroPage         = 0x66
			ZeroPageIndexedX = 0x76
		}
		RTI = @{
			Implied          = 0x40
		}
		RTS = @{
			Implied          = 0x60
		}
		SBC = @{
			Immediate        = 0xE9
			Absolute         = 0xED
			AbsoluteIndexedX = 0xFD
			AbsoluteIndexedY = 0xF9
			ZeroPage         = 0xE5
			ZeroPageIndexedX = 0xF5
			IndexedXIndirect = 0xE1
			IndirectIndexedY = 0xF1
		}
		SEC = @{
			Implied          = 0x38
		}
		SED = @{
			Implied          = 0xF8
		}
		SEI = @{
			Implied          = 0x78
		}
		STA = @{
			Absolute         = 0x8D
			AbsoluteIndexedX = 0x9D
			AbsoluteIndexedY = 0x99
			ZeroPage         = 0x85
			ZeroPageIndexedX = 0x95
			IndexedXIndirect = 0x81
			IndirectIndexedY = 0x91
		}
		STX = @{
			Absolute         = 0x8E
			ZeroPage         = 0x86
			ZeroPageIndexedY = 0x96
		}
		STY = @{
			Absolute         = 0x8C
			ZeroPage         = 0x84
			ZeroPageIndexedX = 0x94
		}
		TAX = @{
			Implied          = 0xAA
		}
		TAY = @{
			Implied          = 0xA8
		}
		TSX = @{
			Implied          = 0xBA
		}
		TXA = @{
			Implied          = 0x8A
		}
		TXS = @{
			Implied          = 0x9A
		}
		TYA = @{
			Implied          = 0x98
		}
	}

	static $OperandSize = [ordered] @{
		Implied				= 0
		Immediate			= 8
		Absolute			= 16
		AbsoluteIndexedX	= 16
		AbsoluteIndexedY	= 16
		ZeroPage			= 8
		ZeroPageIndexedX	= 8
		ZeroPageIndexedY	= 8
		IndexedXIndirect	= 8
		IndirectIndexedY	= 8
		IndirectAbsolute	= 16
		Relative			= 8
	}

	static $AddressingMode = [ordered] @{
		Implied				= [MOS6502AddressingMode]::Implied
		Immediate			= [MOS6502AddressingMode]::Immediate
		Absolute			= [MOS6502AddressingMode]::Absolute
		AbsoluteIndexedX	= [MOS6502AddressingMode]::AbsoluteIndexedX
		AbsoluteIndexedY	= [MOS6502AddressingMode]::AbsoluteIndexedY
		ZeroPage			= [MOS6502AddressingMode]::ZeroPage
		ZeroPageIndexedX	= [MOS6502AddressingMode]::ZeroPageIndexedX
		ZeroPageIndexedY	= [MOS6502AddressingMode]::ZeroPageIndexedY
		IndexedXIndirect	= [MOS6502AddressingMode]::IndexedXIndirect
		IndirectIndexedY	= [MOS6502AddressingMode]::IndirectIndexedY
		IndirectAbsolute	= [MOS6502AddressingMode]::IndirectAbsolute
		Relative			= [MOS6502AddressingMode]::Relative
	}

}
