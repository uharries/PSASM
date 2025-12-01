BeforeAll {
	# Import the module containing Invoke-Assembler
	Import-Module -Name "$PSSCriptRoot\..\src\PASM\PASM.psm1" -ErrorAction Stop -Force

	# Optional: Verify the function exists
	if (-not (Get-Command -Name Invoke-Assembler -ErrorAction SilentlyContinue)) {
		throw "Invoke-Assembler function not found. Ensure the module is loaded correctly."
	}
}

Describe 'Invoke-Assembler Function' {
	BeforeAll {
		$testSource = @(
						'	.org $1234',
						'Start:',
						'	nop',
						'	rts'
						)
		$testSourceHash = 'BDC4EEAA6C4789A1C2ECB316CD46FD27714A183D0F21DED52785FD687CB6C7C2'
		$testSourceFile = "TestDrive:\testSource.s"
		$testOutFile = "TestDrive:\testOut.prg"
		$testPSOutFile = "TestDrive:\testPSOut.ps1"

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
			Invoke-Assembler -SourceFile $testSourceFile -DumpPSfile $testPSOutFile -NoHostOutput
			Test-Path -Path $testPSOutFile | Should -Be $true
		}
	}

	Context 'Output to OutFile' {
		It 'Should write the binary output to the specified file' {
			Invoke-Assembler -SourceFile $testSourceFile -OutFile $testOutFile -NoHostOutput
			Test-Path -Path $testOutFile | Should -Be $true
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

			### Curly tracking in operand area
			@{ code = '.macro mac($val){lda #0};mac(0)'; binary = @(0, 0, 0xa9, 0)}
			@{ code = '.macro mac($val){lda #&{2-2}};mac(0)'; binary = @(0, 0, 0xa9, 0)}

		) {
			($code | Invoke-Assembler -NoHostOutput).Binary | Should -Be $binary
		}
	}

	Context 'Directives' {
		It 'Returns expected <binary> from <code>' -TestCases @(
			@{ code = '.mac mac($x) {lda #$x;};mac(2);mac (4)'; binary = @(0,0,0xa9,2,0xa9,4)}
			@{ code = '.mac mac() {nop;};mac;mac();mac ();mac(  );mac ( )'; binary = @(0,0,0xea,0xea,0xea,0xea,0xea)}
			@{ code = 'class c{c(){}}'; binary = @(0,0)}	# ensure @() patch does not apply to classes
			@{ code = '.fill 5 { $_ * 2 }'; binary = @(0,0,0,2,4,6,8)}
			@{ code = '.repeat 5 { nop }'; binary = @(0,0,0xea,0xea,0xea,0xea,0xea)}
			@{ code = '.org $09f8; .align 256 $ab; nop'; binary = @(0xf8,0x09,0xab,0xab,0xab,0xab,0xab,0xab,0xab,0xab,0xea)}
		) {
			($code | Invoke-Assembler -NoHostOutput).Binary | Should -Be $binary
		}
	}


	Context 'AssemblerPCTracking' {
		It 'Returns expected <binary> from <code>' -TestCases @(
			@{ code = 'for($i=0;$i -lt 3;$i++) {lda :+; :}; lda :+; :'; binary = @(0,0,0xa5,2,0xa5,4,0xa5,6,0xa5,8)}
			@{ code = '.macro mac {lda :+; :}; mac; mac; mac'; binary = @(0,0,0xa5,2,0xa5,4,0xa5,6)}
			@{ code = '.macro mac {:lda :-; :}; mac; mac; mac'; binary = @(0,0,0xa5,0,0xa5,2,0xa5,4)}
			@{ code = '.macro mac{:;lda :+;:};mac'; binary = @(0,0,0xa5,2)}		# adding a label in front, results in first instance resolving to 0... what? ..somthing wrong with the fwd resolver...
			@{ code = '.macro mac(){:lda :-;};.macro mac2(){mac};mac2;mac2;mac2'; binary = @(0,0,0xa5,0,0xa5,2,0xa5,4)}	#calling macros calling macros with labels were an issue...
			@{ code = '.macro mac($addr=mac.end, $x) {lda $addr;end:};mac(254)'; binary = @(0,0,0xa5,0xfe)}
		) {
			($code | Invoke-Assembler -NoHostOutput).Binary | Should -Be $binary
		}
	}

	Context 'ScopeTracking' {
		It 'Returns expected <binary> from <code>' -TestCases @(
			@{ code = '.macro mac($addr=mac.end) {lda $addr;end:}; mac'; binary = @(0,0,0xa5,2)}
			@{ code = '.macro hest(){nop;lab:};hest;lda hest.lab'; binary = @(0,0,0xea,0xa5,1)}
			@{ code = 'lab:{lab2=123;};lda lab.lab2'; binary = @(0,0,0xa5,0x7b)}
		) {
			($code | Invoke-Assembler -NoHostOutput).Binary | Should -Be $binary
		}
	}

	Context 'Complex Stuff' {
		It 'Returns expected <binary> from <code>' -TestCases @(
			@{ code = @'
MySpace = &{

	ConstValue = 10
	.pc $2000
someData:
	.byte 1,2,3,4,5

	.macro noop($count) {
		.fill $count { 0xea }
	}


}
lda MySpace.someData
lda #<MySpace.someData
lda #>MySpace.someData
MySpace.noop(MySpace.ConstValue)
'@
			; binary = @(0,0x20,1,2,3,4,5,0xad,0,0x20,0xa9,0,0xa9,0x20,0xea,0xea,0xea,0xea,0xea,0xea,0xea,0xea,0xea,0xea)}

			) {
			($code | Invoke-Assembler -NoHostOutput).Binary | Should -Be $binary
		}
	}


	AfterAll {
		# Remove-Item -Path $testSourceFile, $testPSOutFile, $testOutFile -Force
	}
}



Describe 'Include File Handling' {
	BeforeEach {
		$testFileA = "TestDrive:\testA.s"
		$testFileB = "TestDrive:\testB.s"
		$testFileC = "TestDrive:\testC.s"
		$testFileD = "TestDrive:\testD.s"
	}

	Context 'PushFile Method' {
		It 'Should detect circular includes and throw an error' {
			Set-Content -Path $testFileA -Value '.include "testB.s"' -Force
			Set-Content -Path $testFileB -Value '.include "testA.s"' -Force

			{ Invoke-Assembler -SourceFile $testFileA -NoHostOutput } | Should -Throw "Circular include detected*"
		}

		It 'Should skip re-inclusion of include-once files' {
			Set-Content -Path $testFileA -Value @('.includeonce; nop') -Force

			$result = ".include '$testFileA'; .include '$testFileA';" | Invoke-Assembler -NoHostOutput
			$result.Binary | Should -Be @(0,0,0xea)
		}

		It 'Should assemble specified source AND all included files' {
			Set-Content -Path $testFileA -Value @(".byte 1;.include '$testFileB'; .byte 3") -Force
			Set-Content -Path $testFileB -Value @('.byte 2') -Force

			$result = ".include '$testFileA'; .include '$testFileB'; .byte 4; .byte 5;" | Invoke-Assembler -NoHostOutput
			$result.Binary | Should -Be @(0,0,1,2,3,2,4,5)
		}
	}

	AfterEach {
		# Cleanup - Pester TestDrive is a bitch, so have to do manual garbage collection...
		[gc]::Collect()
		[gc]::Collect()
		[gc]::Collect()
		$null = Remove-Item -Path $testFileA, $testFileB -Force -ErrorAction SilentlyContinue
		$null = Remove-Item -Path $testFileA, $testFileB -Force -ErrorAction SilentlyContinue
	}
}

AfterAll {
}
