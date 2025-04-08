
Describe 'Invoke-Assembler Function' {
	BeforeAll {
        # Import the module containing Invoke-Assembler
        Import-Module -Name "$PSSCriptRoot\..\src\PASM\PASM.psm1" -ErrorAction Stop -Force

        # Optional: Verify the function exists
        if (-not (Get-Command -Name Invoke-Assembler -ErrorAction SilentlyContinue)) {
            throw "Invoke-Assembler function not found. Ensure the module is loaded correctly."
        }

		$testSource = @(
						'	.org $1234',
						'Start:',
						'	nop',
						'	rts'
						)
		$testSourceHash = 'BDC4EEAA6C4789A1C2ECB316CD46FD27714A183D0F21DED52785FD687CB6C7C2'
		$testSourceFile = "testSource.s"
		$testOutFile = "testOut.prg"
		$testPSOutFile = "testPSOut.ps1"

		Set-Content -Path $testSourceFile -Value $testSource
	}

	Context 'Pipeline input ($Source)' {
		It 'Should process pipeline input and assemble correctly' {
			# Arrange
			$source = $testSource

			# Act
			$result = $source | Invoke-Assembler -NoHostOutput

			# Assert
			$result | Should -Not -BeNullOrEmpty -ErrorAction Stop
			$result.Success | Should -Be $true
			$result.Binary | Should -Be @(0x34,0x12,0xea,0x60)
		}
	}

	Context 'Input via SourceFile' {
		It 'Should read the source from the specified file and assemble' {
			# Arrange
			$sourceFile = $testSourceFile

			# Act
			$result = Invoke-Assembler -SourceFile $sourceFile -NoHostOutput

			# Assert
			$result | Should -Not -BeNullOrEmpty -ErrorAction Stop
			$result.Success | Should -Be $true
			$result.LoadAddress | Should -Be 0x1234
			$result.Binary | Should -Be @(0x34,0x12,0xea,0x60)
		}
	}

	Context 'Output to DumpPSfile' {
		It 'Should write the workSource to the specified file' {
			Invoke-Assembler -Source $testSource -DumpPSfile $testPSOutFile -NoHostOutput
			Test-Path -Path $testPSOutFile | Should -Be $true
		}
	}

	Context 'Output to OutFile' {
		It 'Should write the binary output to the specified file' {
			Invoke-Assembler -Source $testSource -OutFile $testOutFile -NoHostOutput
			Test-Path -Path $testPSOutFile | Should -Be $true
			(Get-FileHash -Algorithm SHA256 $testOutFile).Hash | Should -Be $testSourceHash
		}
	}

	Context 'Error handling' {
		It 'Should throw a syntax error if PASM fails' {
			{ Invoke-Assembler -Source "INVALID CODE" -NoHostOutput } | Should -Throw
		}
	}

	Context 'SYNTAX' {
		It 'Returns expected <binary> from <code>' -TestCases @(
			@{ code = 'nop				// Implied Addressing'; binary = @(0,0,0xea)}
			@{ code = 'lda #$ff			// Immediate Addressing'; binary = @(0,0,0xa9,0xff)}
			@{ code = 'lda #255			// Immediate Addressing'; binary = @(0,0,0xa9,0xff)}
			@{ code = 'lda #-1			// Immediate Addressing'; binary = @(0,0,0xa9,0xff)}
			@{ code = 'lda #-256		// Immediate Addressing'; binary = @(0,0,0xa9,0x00)}
			@{ code = 'inc $d020		// Absolute Addressing'; binary = @(0,0,0xee,0x20,0xd0)}
			@{ code = 'lda $d020,x		// Absolute X Indexed Addressing'; binary = @(0,0,0xbd,0x20,0xd0)}
			@{ code = 'lda $d020 , x	// Absolute X Indexed Addressing'; binary = @(0,0,0xbd,0x20,0xd0)}
			@{ code = 'lda $d020,y		// Absolute Y Indexed Addressing'; binary = @(0,0,0xb9,0x20,0xd0)}
			@{ code = 'lda $d020 , y	// Absolute Y Indexed Addressing'; binary = @(0,0,0xb9,0x20,0xd0)}
			@{ code = 'inc	$02			// Zero Page Addressing'; binary = @(0,0,0xe6,0x02)}
			@{ code = 'lda	$02,x		// Zero Page X Indexed Addressing'; binary = @(0,0,0xb5,0x02)}
			@{ code = 'ldx	$02,y		// Zero Page Y Indexed Addressing'; binary = @(0,0,0xb6,0x02)}
			@{ code = 'jmp ($d020)		// Indirect Absolute Addressing'; binary = @(0,0,0x6c,0x20,0xd0)}
			@{ code = 'lda	($02,x)		// X Indexed Indirect Addressing'; binary = @(0,0,0xa1,0x02)}
			@{ code = 'lda	($02),y		// Indirect Y Indexed Addressing'; binary = @(0,0,0xb1,0x02)}
			@{ code = 'bne 0			// Relative Addressing'; binary = @(0,0,0xd0,0xfe)}

			@{ code = 'lda#$ff'; binary = @(0,0,0xa9,0xff)}
			@{ code = 'lda#255'; binary = @(0,0,0xa9,0xff)}
			@{ code = 'lda#-1'; binary = @(0,0,0xa9,0xff)}
			@{ code = 'lda#-256'; binary = @(0,0,0xa9,0x00)}
			@{ code = 'inc$d020'; binary = @(0,0,0xee,0x20,0xd0)}
			@{ code = 'lda$d020,x'; binary = @(0,0,0xbd,0x20,0xd0)}
			@{ code = 'lda$d020,y'; binary = @(0,0,0xb9,0x20,0xd0)}
			@{ code = 'inc$02'; binary = @(0,0,0xe6,0x02)}
			@{ code = 'lda$02,x'; binary = @(0,0,0xb5,0x02)}
			@{ code = 'ldx$02,y'; binary = @(0,0,0xb6,0x02)}
			@{ code = 'jmp($d020)'; binary = @(0,0,0x6c,0x20,0xd0)}
			@{ code = 'lda($02,x)'; binary = @(0,0,0xa1,0x02)}
			@{ code = 'lda($02),y'; binary = @(0,0,0xb1,0x02)}

			@{ code = ':nop'; binary = @(0,0,0xea)}
			@{ code = 'nop;'; binary = @(0,0,0xea)}
			@{ code = ':nop;'; binary = @(0,0,0xea)}
			@{ code = ':nop;//comment'; binary = @(0,0,0xea)}
			@{ code = 'lda#12'; binary = @(0,0,0xa9,0x0c)}
			@{ code = 'lda#$12'; binary = @(0,0,0xa9,0x12)}
			@{ code = ':lda #12'; binary = @(0,0,0xa9,0x0c)}
			@{ code = 'lda #12;'; binary = @(0,0,0xa9,0x0c)}
			@{ code = ':lda #12;'; binary = @(0,0,0xa9,0x0c)}
			@{ code = ':lda#12;//comment'; binary = @(0,0,0xa9,0x0c)}
			@{ code = ':lda#12//comment'; binary = @(0,0,0xa9,0x0c)}
			@{ code = '//:lda#12'; binary = @(0,0)}
			@{ code = 'lda #12 // comment'; binary = @(0,0,0xa9,0x0c)}
			@{ code = 'lda #12 // comment'; binary = @(0,0,0xa9,0x0c)}
			@{ code = @'
			lda #12
			<# nop lab: :-- #>
			nop
'@
			; binary = @(0,0,0xa9,0x0c,0xea)}
			@{ code = @'
			lda #12
			/* nop lab: :-- */
			nop
'@
			; binary = @(0,0,0xa9,0x0c,0xea)}
			@{ code = 'jmp*'; binary = @(0,0,0x4c,0x00,0x00)}
			@{ code = 'lab: jmp lab'; binary = @(0,0,0x4c,0x00,0x00)}
			@{ code = ':bne :-'; binary = @(0,0,0xd0,0xfe)}
			### I choose not to support this.. labels should be labels, even if they are conflicting with mnemonics
			# @{ code = ':bne:-'; binary = @(0,0,0xd0,0xfe)}
			@{ code = 'lda lab;lab:'; binary = @(0,0,0xa5,0x02)}
			@{ code = '.org $1000;lda lab;lab:'; binary = @(0x00,0x10,0xad,0x03,0x10)}
			@{ code = '.org $1000;lab: lda #12;inc lab+1'; binary = @(0x00,0x10,0xa9,0x0c,0xee,0x01,0x10)}
			@{ code = '.org $1000;lda lab:#12;inc lab'; binary = @(0x00,0x10,0xa9,0x0c,0xee,0x01,0x10)}
			@{ code = '.org $1000;lda :#12;inc :-'; binary = @(0x00,0x10,0xa9,0x0c,0xee,0x01,0x10)}
			@{ code = '.org $1000;lda #12;inc *-1'; binary = @(0x00,0x10,0xa9,0x0c,0xee,0x01,0x10)}

			@{ code = 'bne :+;:'; binary = @(0,0,0xd0,0x00)}
			### Again, I choose not to support this.. labels should be labels, even if they are conflicting with mnemonics
			# @{ code = 'bne:+;:'; binary = @(0,0,0xd0,0x00)}

			@{ code = '.org (6145%$1000);lda#%11011'; binary = @(0x01,0x08,0xa9,0x1b)}
			@{ code = '.pc (6145%%1000);lda#%100%3'; binary = @(0x01,0x00,0xa9,0x01)}
			@{ code = '.pc (3*$12);lda#$100%$a'; binary = @(0x36,0x00,0xa9,0x06)}

			@{ code = '.text "ABCabc",0'; binary = @(0, 0, 65, 66, 67, 97, 98, 99, 0)}
			@{ code = ".text 'ABCabc',0"; binary = @(0, 0, 65, 66, 67, 97, 98, 99, 0)}
			@{ code = '.text "ABCabc",0 -AsPETSCII'; binary = @(0, 0, 97, 98, 99, 65, 66, 67, 0)}
			@{ code = '.text "ABCabc",0 -AsPETSCII:$false'; binary = @(0, 0, 65, 66, 67, 97, 98, 99, 0)}
			@{ code = '.ascii "ABCabc",0'; binary = @(0, 0, 65, 66, 67, 97, 98, 99, 0)}
			@{ code = '.petscii "ABCabc",0'; binary = @(0, 0, 97, 98, 99, 65, 66, 67, 0)}
			@{ code = '.petscii "ABC",''abc'',0'; binary = @(0, 0, 97, 98, 99, 65, 66, 67, 0)}

		) {
			($code | Invoke-Assembler -NoHostOutput).Binary | Should -Be $binary
		}
	}

	AfterAll {
		Remove-Item -Path $testSourceFile, $testPSOutFile, $testOutFile -Force
	}
}
