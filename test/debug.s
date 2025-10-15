/*****************************************************************************\
*** MACROS ********************************************************************
\*****************************************************************************/

.macro BasicPrgHeader($BasicLineNumber=$null, $Address=BasicPrgHeader.end) {
//.macro BasicPrgHeader($Address=BasicPrgHeader.end, $BasicLineNumber=(Get-Date).Year) {
// The PowerShell parser does not allow multiple default parameters following a complex one - This is a way to work around that
	if ($null -eq $BasicLineNumber) { $BasicLineNumber = (Get-Date).Year }
	.pc $0801
	.word	:+, $BasicLineNumber		// Link to next BASIC Line, line number
	.text	$9e, ($Address).ToString(), 0	// SYS, Textual representation of addr, end of BASIC line
:	.word	0				// BASIC end marker
end:
}

.macro OnSpace($addr) {
	lda	#$7f
	sta	$dc00
	lda	$dc01
	cmp	#$ef
	beq	$addr
}

.macro .fill {
	param ([ValidateRange(1,[int]::MaxValue)][int]$count,[scriptblock]$data)
	.byte (0..($count-1) | ForEach-Object $data)
}

.macro PutXYC($screenram,$x,$y,$val,$col) {
	PutXY($screenram,$x,$y,$val)
	PutXY($d800,$x,$y,$col)
}

.macro PutXY([uint16]$base,$x,$y,[byte[]]$val) {
	$val | ForEach-Object {
		lda	#$_
		sta	$base + $x + 40 * $y
		$x++
	}
}

function PETSCII([string]$s) {
	$s.ToCharArray() | ForEach-Object {
		$code = [byte]$_
		if ($code -ge 97 -and $code -le 122) { $code -= 32 } # a-z to A-Z
		elseif ($code -ge 65 -and $code -le 90) { $code -= 64 } # A-Z to shifted
		elseif ($code -eq 64) { $code = 0 } # @ to space
		elseif ($code -eq 91) { $code = 27 } # [ to £
		elseif ($code -eq 92) { $code = 29 } # \ to ↑
		elseif ($code -eq 93) { $code = 28 } # ] to ↓
		elseif ($code -eq 94) { $code = 30 } # ^ to →
		elseif ($code -eq 95) { $code = 31 } # _ to ←
		elseif ($code -ge 123 -and $code -le 126) { $code -= 64 } # {-|}~
		$code
	}
}

.macro SetCursor ($x, $y) {
	lda	#$x
	sta	211
	lda	#$y
	sta	214
}

.macro CursorBlink {

}

class Cursor {
	[uint16]$Screen
	[int]$PosX
	[int]$PosY

	Cursor([uint16]$screen, [int]$x, [int]$y) {
		$this.Screen = $screen
		$this.PosX = $x
		$this.PosY = $y
	}

	static RuntimeVars() {
		PosX:	.byte 0
		PosY:	.byte 0
	}

	On() {
		lda	$this.Screen + $this.PosX + 40 * $this.PosY
		ora	#$80
		sta	$this.Screen + $this.PosX + 40 * $this.PosY
	}

	Off() {
		lda	$this.Screen + $this.PosX + 40 * $this.PosY
		and	#$7f
		sta	$this.Screen + $this.PosX + 40 * $this.PosY
	}

	WaitFrames($count) {
		ldx	#$count
		lda	#0
	:	cmp	$d012
		bne	:-
		bit	$d011
		bmi	:-
		dex
		bne	:-
	}

	Blink([int]$times) {
		ldy	#$times
	:	$this.WaitFrames(60)
		$this.On()
		$this.WaitFrames(60)
		$this.Off()
		dey
		bpl	:-
	}

	Right() {
		$this.Off()
		inc	CursorPosX
		if ($this.PosX -ge 40) { $this.PosX = 0; $this.PosY++ }
		if ($this.PosY -ge 25) { $this.PosY = 0 }
		$this.On()
	}
	Left() {
		$this.Off()
		$this.PosX--
		if ($this.PosX -lt 0) { $this.PosX = 39; $this.PosY-- }
		if ($this.PosY -lt 0) { $this.PosY = 24 }
		$this.On()
	}
	Up() {
		$this.Off()
		$this.PosY--
		if ($this.PosY -lt 0) { $this.PosY = 24 }
		$this.On()
	}
	Down() {
		$this.Off()
		$this.PosY++
		if ($this.PosY -ge 25) { $this.PosY = 0 }
		$this.On()
	}
}



.macro WaitFrames($count) {
	ldx	#$count
	lda	#0
:	cmp	$d012
	bne	:-
	bit	$d011
	bmi	:-
	dex
	bne	:-
}

.macro CursorOn() {
	tya
	pha
	ldy	#0
	lda	(zpCursorPos),y
	ora	#$80
	sta	(zpCursorPos),y
	pla
	tay
}

.macro CursorOff() {
	tya
	pha
	ldy	#0
	lda	(zpCursorPos),y
	and	#$7f
	sta	(zpCursorPos),y
	pla
	tay
}

.macro CursorInit() {
	lda	214
	sta	zpCursorY
	lda	211
	sta	zpCursorX
	CursorUpdate
}

.macro CursorBlink([int]$times) {
	ldy	#$times
:	WaitFrames 60
	CursorOn
	WaitFrames 60
	CursorOff
	dey
	bpl	:-
}

.macro CursorRight() {
	CursorOff
	ldx	zpCursorX
	inx
	cpx	#40
	bne	:+
	ldx	#0
	stx	zpCursorX
	inc	zpCursorY
	ldy	zpCursorY
	cpy	#25
	bne	:+
	ldy	#0
	sty	zpCursorY
:
	WaitFrames 3
	CursorOn
	WaitFrames 60
}

.macro CursorLeft() {
	CursorOff
	ldx	zpCursorX
	dex
	cpx	#255
	bne	:+
	ldx	#39
	stx	zpCursorX
	dec	zpCursorY
	ldy	zpCursorY
	cpy	#255
	bne	:+
	ldy	#24
	sty	zpCursorY
:
	CursorOn
	WaitFrames 60
}

.macro CursorUp() {
	CursorOff
	dec	zpCursorY
	ldy	zpCursorY
	cpy	#255
	bne	:+
	ldy	#24
	sty	zpCursorY
:
	CursorOn
	WaitFrames 60
}

.macro CursorDown($times) {
	.repeat( $times, {
		CursorOff
		inc	zpCursorY
		ldy	zpCursorY
		cpy	#25
		bne	:+
		ldy	#0
		sty	zpCursorY
	:
		WaitFrames 3
		CursorUpdate
		CursorOn
		WaitFrames 60
	})
}

.macro CursorUpdate() {
	lda	$288
	sta	zpCursorPos+1
	lda	#0
	sta	zpCursorPos
	ldy	zpCursorY
:	clc
	adc	#40
	bcc	:+
	inc	zpCursorPos+1
:	dey
	bne	:--
	clc
	adc	zpCursorX
	sta	zpCursorPos
	bcc	:+
	inc	zpCursorPos+1
:
}

.macro .repeat {
	[Alias('.rep')]
	param ([int]$count,[scriptblock]$data)
	0..($count-1) | %{$data.Invoke()}
}


MySpace = &{

	ConstValue = 10
	.pc $2000
someData:
	.byte 1,2,3,4,5

	.macro noop($count) {
		.fill $count { 0xea }
	}


}

/*****************************************************************************\
*** STARTUP *******************************************************************
\*****************************************************************************/
.pc ($100-4)
zpCursorX:
.pc ($100-3)
zpCursorY:
.pc ($100-2)
zpCursorPos:

	BasicPrgHeader()

	lda	#MySpace.ConstValue
	lda	MySpace.someData
	MySpace.noop(10)

	$GoToAddress = 0x0400 + 23 * 40 + 33

	CursorInit()
	CursorBlink(3)
	CursorDown(5)
	rts
Main:
//	dec	$d021
	OnSpace(Exxit)
	jmp	Main

	ldx	#0		//Nice nasty loop generating 8 jitter variants when interrupted!
:	inc	$0400,x
	bpl	:-
	bmi	:-

	jmp	Main

Exxit:
	rts
