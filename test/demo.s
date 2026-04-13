/*
** C style block comment with anonymous label reference for max confusion :++
*/

.macro Wait([ValidateRange(2,128kb)][int]$num) {
	if ($num%2 -eq 0) {
		.rep ($num/2) {nop;}
	} else {
		if($num -ge 3) {
			.byte	$04,$00
			.rep  (($num-3)/2) {nop;}
		}
	}
}

.macro WaitScanline($line) {
	lda	#<($line)
:	cmp	$d012
	bne	:-
	bit	$d011
	if ($line -le 255) {
		bmi	:-
	} else {
		bpl	:-
	}
}

# .macro OnSpace($addr) {
# 	lda	#$7f
# 	sta	$dc00
# 	lda	$dc01
# 	and	#$10
# 	beq	$addr
# }

.macro BasicPrgHeader($Address=$null, $BasicLineNumber=(Get-Date).Year) {
	if ($null -eq $Address) { $Address = :++ }
	.pc $0801
	.word	:+, 1				// Link to next BASIC Line
	.text	$9e, ($Address)?.ToString(), 0	// SYS, Textual representation of addr, end of BASIC line
:	.word	0				// BASIC end marker
:
}

.macro BasicPrgHeader2($addr=$null, $txt="") {
	if ($null -eq $addr) { $addr = Next + 2 }
	.pc $0801
Head:
	.word	Next				// Link to next BASIC Line
	.word	1				// Line number
	.byte	$9E				// SYS
	.text	($addr)?.ToString()		// Textual representation of addr
	.byte	10				// End of line, making BASIC execute the SYS and ignore the rest
	.fill	10 {20}				// backspace 10 times to delete the display of the SYS call
	.ascii	$txt				// ..well it gives a syntax error upon return, but that will never happen in a demo
	.byte	0				// End of BASIC line
Next:	.word	0				// BASIC end marker
}

class c64lib {
	$blah

	oOnSpace($addr) {
		lda	#$7f
		sta	$dc00
		lda	$dc01
		and	#$10
		beq	$addr
	}
	static OnSpace($addr) {
		lda	#$7f
		sta	$dc00
		lda	$dc01
		and	#$10
		beq	$addr
	}

	c64lib() {}
}

class IRQTools {
	Set($irqHandler, $scanLine) {
		lda	#>$irqHandler
		sta	$ffff
		lda	#<$irqHandler
		sta	$fffe
		lda	$d011
		and	#$7f
		ora	#>$scanLine
		sta	$d011
		lda	#<$scanLine
		sta	$d012
	}

	WaitScanLine($scanLine) {
		$this.Set(:+,$scanLine)
		lda	#$8f
		sta	$d019
		rti
	:
		// Next IRQ will enter here, when $scanline is reached
	}
}



	$c64lib = [c64lib]::new()
	$irq = [IRQTools]::new()

	# .org $0801
	# .byte $0b, $08, $0a, $00, $9e, $32, $30, $36, $31, $00, $00, $00

	# Wait 5
	# .fill 10 {$de,(2*$_),$ad}
	# .byte (0..9|%{$aa,$55,$_*2})

	# BasicPrgHeader Start "ANCIENTS 2025"
	BasicPrgHeader
Start:
	jsr	Init
	$irq.Set(IRQH,$70)
	lda	#$35
	sta	$01
	lda	#$01
	sta	$d01a
	cli
Main:
	jmp	*
	WaitScanLine($50)

	ldy	#$54
	ldx	#16
:	dec	$d020
	cpy	$d012
	bne	*-3
	1..4|%{iny;}
	bne	:-

	[c64lib]::OnSpace(:+)
	$c64lib.oOnSpace(:+)
	jmp	Main
:
	rts

Init:
	sei
	lda	#$7f		//Diable all CIA Interrupts
	sta	$dc0d		//From CIA 1 (IRQ)
	sta	$dd0d		//From CIA 2 (NMI)
	lda	$dc0d		//Ack / clear all pending CIA 1 (IRQ) interrupts
	lda	$dd0d		//Ack / clear all pending CIA 2 (NMI) interrupts
	rts

IRQH:
	dec	$0400
	$irq.WaitScanLine($80)
	dec	$0401
	$irq.WaitScanLine($90)
	dec	$0402
	$irq.WaitScanLine($a0)
	dec	$0403
	$irq.WaitScanLine($b0)
	dec	$0404
	$irq.Set(IRQH,$70)
	dec $0405
	rti
