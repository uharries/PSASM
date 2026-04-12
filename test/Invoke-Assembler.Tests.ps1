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


Describe 'Segment Handling' {
	Context 'Segments' {

		#
		# Explicit Start
		#
		It 'Places code at explicit addresses <code>' -TestCases @(
			@{
				code   = '.segment code -Start $1000; lda #1'
				binary = @(0x00,0x10, 0xa9,1)
			}
			@{
				code   = '.segment data -Start $1200; .fill 3 { $_ }'
				binary = @(0x00,0x12, 0,1,2)
			}
		) {
			($code | Invoke-Assembler -NoHostOutput).Binary | Should -Be $binary
		}

		#
		# Virtual segments (occupy space, emit nothing)
		#
		It 'Supports virtual segments and places following code correctly' -TestCases @(
			@{
				code = @'
	.segment v -Virtual
		.fill 5 { 0 }
	.segment code -StartAfter v
		lda #7
'@
				binary = @(0x05,0x00, 0xa9,7)   # virtual = 5 bytes offset
			}
		) {
			($code | Invoke-Assembler -NoHostOutput).Binary | Should -Be $binary
		}

		#
		# StartAfter
		#
		It 'Resolves segments using StartAfter' -TestCases @(
			@{
				code = @'
	.segment first -Start $0800
		lda #1
	.segment second -StartAfter first
		lda #2
'@
				binary = @(0x00,0x08, 0xa9,1, 0xa9,2)
			}
		) {
			($code | Invoke-Assembler -NoHostOutput).Binary | Should -Be $binary
		}

		#
		# pushsegment / popsegment
		#
		It 'Supports pushsegment / popsegment' -TestCases @(
			@{
				code = @'
	.segment code -Start 2
		lda #1
	.pushsegment data -StartAfter code
		.fill 2 { $_ }
	.popsegment
		lda #3
'@
				binary = @(0x02,0x00, 0xa9,1, 0xa9,3 ,0,1)
			}
		) {
			($code | Invoke-Assembler -NoHostOutput).Binary | Should -Be $binary
		}

		#
		# Size limit (should throw)
		#
		It 'Throws when segment exceeds -Size' -TestCases @(
			@{
				code     = '.segment small -Size 1; lda #1; lda #2'
				expected = "Segment 'small' exceeds defined Size of 0x0001 with actual size 0x0004"
			}
		) {
			{ $code | Invoke-Assembler -NoHostOutput } |
				Should -Throw $expected
		}

		#
		# End limit (should throw)
		#
		It 'Throws when segment exceeds -End' -TestCases @(
			@{
				code = '.segment s -Start $1000 -End $1001; lda #1; lda #2'
				expected = "Segment 's' exceeds defined End at 0x1001 with actual end address 0x1003"
			}
		) {
			{ $code | Invoke-Assembler -NoHostOutput } |
				Should -Throw $expected
		}

		#
		# Overlap detection
		#
		It 'Throws on overlapping segments' -TestCases @(
			@{
				code = @'
	.segment a -Start $2000
		lda #1
	.segment b -Start $2001
		lda #2
'@
				expected = "Segment 'b' overlaps 'a' at address 0x2001"
			}
		) {
			{ $code | Invoke-Assembler -NoHostOutput } |
				Should -Throw $expected
		}

		#
		# Ordering: mixed virtual + real
		#
		It 'Emits final binary in correct segment order' -TestCases @(
			@{
				code = @'
	.segment v1 -Virtual
		.fill 3 {0}

	.segment code1 -StartAfter v1
		lda #9

	.segment v2 -StartAfter code1 -Virtual
		.fill 2 {0}

	.segment code2 -StartAfter v2
		lda #4
'@
				binary = @(3,0,0xA9,9, 0,0, 0xA9,4)
			}
		) {
			($code | Invoke-Assembler -NoHostOutput).Binary | Should -Be $binary
		}

		#
		# Alignment
		#
		It 'Aligns segment start forward with positive Align' -TestCases @(
			@{code = '.segment a -Start $1001 -Align 4; lda #1' ; binary = @(0x04,0x10,0xA9,1)}
		) {
			($code | Invoke-Assembler -NoHostOutput).Binary | Should -Be $binary
		}

		It 'Aligns segment from end with negative Align' -TestCases @(
			@{code = '.segment a -End 7 -Align -1; lda #1' ; binary = @(0,0,0,0,0,0,0,0,0xA9,1)}
			@{code = '.segment a -End $ff -Align -256; lda #1' ; binary = @(0,0,0xA9,1) + @(0) * 254}
		) {
			($code | Invoke-Assembler -NoHostOutput).Binary | Should -Be $binary
		}

		It 'Throws on invalid alignments' -TestCases @(
			@{
				code = '.segment a -Align -1; lda #1'
				expected = "Cannot find end of address space for segment 'a'"
			}
		) {
			{ $code | Invoke-Assembler -NoHostOutput } |
				Should -Throw $expected
		}


	}
}



Describe 'Segment Handling' {
    Context 'Placement' {
        It 'Places code at explicit start address' -TestCases @(
            @{ code = '.segment a -Start $1000; lda #1' ; binary = @(0x00,0x10, 0xA9,1) }
        ) { ($code | Invoke-Assembler -NoHostOutput).Binary | Should -Be $binary }

        It 'Derives start from End and Size' -TestCases @(
            @{ code = '.segment a -End $1003 -Size 4; lda #1' ; binary = @(0x00,0x10, 0xA9,1) }
        ) { ($code | Invoke-Assembler -NoHostOutput).Binary | Should -Be $binary }

        It 'Derives end from Start and Size' -TestCases @(
            @{ code = '.segment a -Start $1000 -Size 4; lda #1' ; binary = @(0x00,0x10, 0xA9,1) }
        ) { ($code | Invoke-Assembler -NoHostOutput).Binary | Should -Be $binary }

        It 'Derives size from Start and End' -TestCases @(
            @{ code = '.segment a -Start $1000 -End $1003; lda #1' ; binary = @(0x00,0x10, 0xA9,1) }
        ) { ($code | Invoke-Assembler -NoHostOutput).Binary | Should -Be $binary }
    }

    Context 'StartAfter' {
        It 'Places segment immediately after another' -TestCases @(
            @{
                code = @'
.segment a -Start $1000; lda #1
.segment b -StartAfter a; lda #2
'@
                binary = @(0x00,0x10, 0xA9,1, 0xA9,2)
            }
        ) { ($code | Invoke-Assembler -NoHostOutput).Binary | Should -Be $binary }

        It 'Chains multiple StartAfter segments' -TestCases @(
            @{
                code = @'
.segment a -Start $0800; lda #1
.segment b -StartAfter a; lda #2
.segment c -StartAfter b; lda #3
'@
                binary = @(0x00,0x08, 0xA9,1, 0xA9,2, 0xA9,3)
            }
        ) { ($code | Invoke-Assembler -NoHostOutput).Binary | Should -Be $binary }

        It 'StartAfter works with Size constraint' -TestCases @(
            @{
                code = @'
.segment a -Start $1000; lda #1
.segment b -StartAfter a -Size 4; lda #2
'@
                binary = @(0x00,0x10, 0xA9,1, 0xA9,2)
            }
        ) { ($code | Invoke-Assembler -NoHostOutput).Binary | Should -Be $binary }

        It 'StartAfter works with End constraint' -TestCases @(
            @{
                code = @'
.segment a -Start $1000; lda #1
.segment b -StartAfter a -End $1005; lda #2
'@
                binary = @(0x00,0x10, 0xA9,1, 0xA9,2)
            }
        ) { ($code | Invoke-Assembler -NoHostOutput).Binary | Should -Be $binary }
    }

    Context 'Fill' {
        It 'Fills segment to End with default fill byte' -TestCases @(
            @{ code = '.segment a -Start $1000 -End $1003 -Fill; lda #1' ; binary = @(0x00,0x10, 0xA9,1,0,0) }
        ) { ($code | Invoke-Assembler -NoHostOutput).Binary | Should -Be $binary }

        It 'Fills with custom single FillByte' -TestCases @(
            @{ code = '.segment a -Start $1000 -End $1003 -Fill -FillBytes $FF; lda #1' ; binary = @(0x00,0x10, 0xA9,1,0xFF,0xFF) }
        ) { ($code | Invoke-Assembler -NoHostOutput).Binary | Should -Be $binary }

        It 'Fills with repeating FillBytes pattern' -TestCases @(
            @{ code = '.segment a -Start $1000 -End $1005 -Fill -FillBytes $AA,$BB; lda #1' ; binary = @(0x00,0x10, 0xA9,1,0xAA,0xBB,0xAA,0xBB) }
        ) { ($code | Invoke-Assembler -NoHostOutput).Binary | Should -Be $binary }

        It 'Fills segment to Size' -TestCases @(
            @{ code = '.segment a -Start $1000 -Size 4 -Fill; lda #1' ; binary = @(0x00,0x10, 0xA9,1,0,0) }
        ) { ($code | Invoke-Assembler -NoHostOutput).Binary | Should -Be $binary }
    }

    Context 'Alignment' {
        It 'Aligns segment start forward with positive Align' -TestCases @(
            @{ code = '.segment a -Start $1001 -Align 4; lda #1' ; binary = @(0x04,0x10, 0xA9,1) }
            @{ code = '.segment a -Start $1000 -Align 4; lda #1' ; binary = @(0x00,0x10, 0xA9,1) }  # already aligned
            @{ code = '.segment a -Start $1001 -Align 256; lda #1' ; binary = @(0x00,0x11, 0xA9,1) }  # page align
        ) { ($code | Invoke-Assembler -NoHostOutput).Binary | Should -Be $binary }

        It 'Positive Align with Fill pads before aligned content' -TestCases @(
            @{ code = '.segment a -Start $1001 -End $1005 -Align 4 -Fill; lda #1' ; binary = @(0x01,0x10, 0,0,0, 0xA9,1) }
        ) { ($code | Invoke-Assembler -NoHostOutput).Binary | Should -Be $binary }

        It 'Negative Align anchors content to alignment boundary near end' -TestCases @(
            @{ code = '.segment a -End 7 -Align -1; lda #1' ; binary = @(0,0, 0,0,0,0,0,0, 0xA9,1) }
            @{ code = '.segment a -End $ff -Align -256; lda #1' ; binary = @(0,0, 0xA9,1) + @(0) * 254 }
        ) { ($code | Invoke-Assembler -NoHostOutput).Binary | Should -Be $binary }

        It 'Negative Align with explicit Start fills full range' -TestCases @(
            @{ code = '.segment a -Start $1000 -End $100f -Align -8 -FillBytes $EA; lda #1' ; binary = @(0x00,0x10, 0xEA,0xEA,0xEA,0xEA,0xEA,0xEA,0xEA,0xEA, 0xA9,1,0xEA,0xEA,0xEA,0xEA,0xEA,0xEA) }
        ) { ($code | Invoke-Assembler -NoHostOutput).Binary | Should -Be $binary }
    }

    Context 'Virtual' {
        It 'Virtual segment emits no bytes' -TestCases @(
            @{
                code = @'
.segment v -Start $1000 -Virtual; lda #1
.segment r -StartAfter v; lda #2
'@
                binary = @(0x02,0x10, 0xA9,2)
            }
        ) { ($code | Invoke-Assembler -NoHostOutput).Binary | Should -Be $binary }

        It 'Virtual segment still advances address for StartAfter' -TestCases @(
            @{
                code = @'
.segment v -Virtual; .fill 5 { 0 }
.segment r -StartAfter v; lda #1
'@
                binary = @(0x05,0x00, 0xA9,1)
            }
        ) { ($code | Invoke-Assembler -NoHostOutput).Binary | Should -Be $binary }
    }

    Context 'AllowOverlap' {
        It 'Allows segment to be overlapped when AllowOverlap is set' -TestCases @(
            @{
                code = @'
.segment a -Start $1000 -Size 4 -Fill -AllowOverlap
.segment b -Start $1002; lda #1
'@
                binary = @(0x00,0x10, 0,0, 0xA9,1)
            }
        ) { ($code | Invoke-Assembler -NoHostOutput).Binary | Should -Be $binary }

        It 'Later segment overwrites fill of earlier AllowOverlap segment' -TestCases @(
            @{
                code = @'
.segment a -Start $1000 -Size 4 -Fill -FillBytes $FF -AllowOverlap
.segment b -Start $1002; lda #1
'@
                binary = @(0x00,0x10, 0xFF,0xFF, 0xA9,1)
            }
        ) { ($code | Invoke-Assembler -NoHostOutput).Binary | Should -Be $binary }
    }

    Context 'Re-entry' {
        It 'Switching back to a segment continues emitting into it' -TestCases @(
            @{
                code = @'
.segment a -Start $1000; lda #1
.segment b -Start $1010; lda #2
.segment a; lda #3
'@
                binary = @(0x00,0x10, 0xA9,1,0xA9,3) + @(0)*12 + @(0xA9,2)
            }
        ) { ($code | Invoke-Assembler -NoHostOutput).Binary | Should -Be $binary }

        It 'Re-entry ignores repeated parameters silently' -TestCases @(
            @{
                code = @'
.segment a -Start $1000; lda #1
.segment a -Start $2000; lda #2
'@
                binary = @(0x00,0x10, 0xA9,1,0xA9,2)  # $2000 is ignored
            }
        ) { ($code | Invoke-Assembler -NoHostOutput).Binary | Should -Be $binary }
    }

    Context 'Push/Pop' {
        It 'Pushsegment and popsegment restore context correctly' -TestCases @(
            @{
                code = @'
.segment code -Start 2; lda #1
.pushsegment data -StartAfter code; .fill 2 { $_ }
.popsegment; lda #3
'@
                binary = @(0x02,0x00, 0xA9,1,0xA9,3, 0,1)
            }
        ) { ($code | Invoke-Assembler -NoHostOutput).Binary | Should -Be $binary }

        It 'Nested push/pop restores correct segment at each level' -TestCases @(
            @{
                code = @'
.segment a -Start $1000; lda #1
.pushsegment b -Start $2000; lda #2
.pushsegment c -Start $3000; lda #3
.popsegment; lda #4
.popsegment; lda #5
'@
                binary = @(0x00,0x10, 0xA9,1,0xA9,5) + @(0)*0xFFc + @(0xA9,2,0xA9,4) + @(0)*0xFFc + @(0xA9,3)
            }
        ) { ($code | Invoke-Assembler -NoHostOutput).Binary | Should -Be $binary }
    }

    Context 'Error cases' {
        It 'Throws on invalid parameter combinations' -TestCases @(
            @{ code = '.segment a -Start $1000 -End $1003 -Size 4; lda #1' ; expected = "Cannot specify both End and Size*" }
            @{ code = '.segment a -Start $1000 -StartAfter b; lda #1'      ; expected = "Cannot specify both Start and StartAfter*" }
            @{ code = '.segment a -StartAfter b -End $1003 -Size 4'        ; expected = "Cannot specify both End and Size*" }
        ) { { $code | Invoke-Assembler -NoHostOutput } | Should -Throw $expected }

        It 'Throws when segment exceeds Size' -TestCases @(
            @{ code = '.segment a -Size 1; lda #1; lda #2' ; expected = "Segment 'a' exceeds defined Size*" }
        ) { { $code | Invoke-Assembler -NoHostOutput } | Should -Throw $expected }

        It 'Throws when segment exceeds End' -TestCases @(
            @{ code = '.segment a -Start $1000 -End $1001; lda #1; lda #2' ; expected = "Segment 'a' exceeds defined End*" }
        ) { { $code | Invoke-Assembler -NoHostOutput } | Should -Throw $expected }

        It 'Throws on overlap without AllowOverlap' -TestCases @(
            @{
                code = @'
.segment a -Start $2000; lda #1
.segment b -Start $2001; lda #2
'@
                expected = "Segment 'b' overlaps 'a'*"
            }
        ) { { $code | Invoke-Assembler -NoHostOutput } | Should -Throw $expected }

        It 'Throws on negative align without End' -TestCases @(
            @{ code = '.segment a -Align -1; lda #1' ; expected = "Cannot find end of address space*" }
        ) { { $code | Invoke-Assembler -NoHostOutput } | Should -Throw $expected }

        It 'Throws on stack underflow' -TestCases @(
            @{ code = '.popsegment' ; expected = "Segment stack underflow*" }
        ) { { $code | Invoke-Assembler -NoHostOutput } | Should -Throw $expected }
    }

	Context 'Run Address' {
		It 'Labels resolve to run address, bytes placed at load address' -TestCases @(
			@{
				code   = '.segment c -Start $1000 -Run $2000; lab: lda lab'
				binary = @(0x00,0x10, 0xAD,0x00,0x20)  # bytes at $1000, label resolves to $2000
			}
		) { ($code | Invoke-Assembler -NoHostOutput).Binary | Should -Be $binary }

		It 'Multiple labels all resolve to run address space' -TestCases @(
			@{
				code = @'
.segment c -Start $1000 -Run $2000
lab1: lda lab1
	lda lab2
lab2: nop
'@
				binary = @(0x00,0x10, 0xAD,0x00,0x20, 0xAD,0x06,0x20, 0xEA)
			}
		) { ($code | Invoke-Assembler -NoHostOutput).Binary | Should -Be $binary }

		It 'Run address does not affect binary load position' -TestCases @(
			@{
				# Two segments at same load addresses but different run addresses
				# should still be placed correctly in binary
				code = @'
.segment a -Start $1000 -Run $2000
	nop
.segment b -StartAfter a -Run $3000
	nop
'@
				binary = @(0x00,0x10, 0xEA, 0xEA)
			}
		) { ($code | Invoke-Assembler -NoHostOutput).Binary | Should -Be $binary }

		It 'PC is run-address based within segment' -TestCases @(
			@{
				# .word * should emit the run address, not load address
				code   = '.segment c -Start $1000 -Run $2000; .word *'
				binary = @(0x00,0x10, 0x00,0x20)
			}
		) { ($code | Invoke-Assembler -NoHostOutput).Binary | Should -Be $binary }

		It 'Without -Run, PC equals load address' -TestCases @(
			@{
				code   = '.segment c -Start $1000; lab: lda lab'
				binary = @(0x00,0x10, 0xAD,0x00,0x10)
			}
		) { ($code | Invoke-Assembler -NoHostOutput).Binary | Should -Be $binary }

		It 'Run address works with StartAfter' -TestCases @(
			@{
				code = @'
.segment a -Start $1000
	nop
.segment b -StartAfter a -Run $2000
	lab: lda lab
'@
				binary = @(0x00,0x10, 0xEA, 0xAD,0x00,0x20)
			}
		) { ($code | Invoke-Assembler -NoHostOutput).Binary | Should -Be $binary }
	}
}



AfterAll {
}
