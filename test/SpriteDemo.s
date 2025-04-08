/*****************************************************************************\
*
*         FILE: SpriteDemo.s
*      VERSION: 0.1
*    LAST EDIT: 2025.04.07 22:35:00
*       AUTHOR: Ulf Diabelez Harries
*    COPYRIGHT: (c)2025 by Ulf Diabelez Harries
*
* ARCHITECTURE: CBM Commodore 64 and compatibles
*    ASSEMBLER: PASM
*      OPTIONS: -
*
*  DESCRIPTION: Small Sprite Demo showcasing the PASM Assembler
*       STATUS: Under Development
*         BUGS: NONE =)
*
\*****************************************************************************/

/*****************************************************************************\
*** MACROS ********************************************************************
\*****************************************************************************/

.macro BasicPrgHeader($Address=:++, $BasicLineNumber=(Get-Date).Year) {
	.pc $0801
	.word	:+, $BasicLineNumber		// Link to next BASIC Line
	.text	$9e, ($Address).ToString(), 0	// SYS, Textual representation of addr, end of BASIC line
:	.word	0				// BASIC end marker
:
}

.macro IDisable() {
	sei
	lda	#$7f		// Diable all CIA Interrupts
	sta	$dc0d		// From CIA 1 (IRQ)
	sta	$dd0d		// From CIA 2 (NMI)
	lda	$dc0d		// Ack / clear all pending CIA 1 (IRQ) interrupts
	lda	$dd0d		// Ack / clear all pending CIA 2 (NMI) interrupts
}

.macro IEnable() {
	lda	#$35
	sta	$01
	lda	#$01
	sta	$d01a
	cli
}

.macro ISet($irqHandler, $scanLine) {
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

.macro IWaitScanLine($scanLine) {
	ISet	:+ $scanLine
	lda	#$8f
	sta	$d019
	rti
:
	// Next IRQ will enter here, when $scanline is reached
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


/*****************************************************************************\
*** STARTUP *******************************************************************
\*****************************************************************************/

	BasicPrgHeader
	IDisable
	jsr	SpriteInit
	ISet	IRQ 250
	IEnable
Main:
//	dec	$d021
	OnSpace	Exit
	jmp	Main

Exit:
	lda	#$37
	sta	$01
	jmp	64738

IRQ:
//	dec	$d020
//	lda	$d011
//	and	#%11110111
//	sta	$d011
	IWaitScanLine 256
	jsr	SpriteUpdate
//	lda	$d011
//	ora	#%00001000
//	sta	$d011
//	inc	$d020
	ISet	IRQ 250
	lda	#$8f
	sta	$d019
	rti

/*****************************************************************************\
*** SPRITE STUFF **************************************************************
\*****************************************************************************/

SpriteInit:
	ldx	#$35
	ldy	#$90
	for($i=0;$i -lt 16;$i+=2) {
		stx	$d000+$i
		sty	$d001+$i
	}

	0..7 | %{
		lda	#<((SpriteData % $4000 / $40)+$_)
		sta	$0400+$03f8+$_
	}

	lda	#14
	sta	$d025		//Sprite Multicolor 0
	lda	#7
	sta	$d026		//Sprite Multicolor 1
	lda	#1
	sta	$d027		//Sprite 0 color
	sta	$d028		//..1..
	sta	$d029		//
	sta	$d02a
	sta	$d02b
	sta	$d02c
	sta	$d02d
	sta	$d02e

	lda	#$ff
	sta	$d015
	sta	$d01c		//Sprite Multicolor
	rts

.macro UpdSprite($spr) {
	ldx	sprxpos+$spr
	lda	XDataLo,x
	sta	$d000+$spr*2
	lda	XDataHi,x
	tay
	lda	$d010
	and	tabd010and+$spr
	ora	tabd010or+$spr*2,y
	sta	$d010
	inx
	inx
	stx	sprxpos+$spr

	ldy	sprypos+$spr
	lda	YDataLo,y
	sta	$d001+$spr*2
	iny
	iny
	iny
	sty	sprypos+$spr
}

SpriteUpdate:
	0..7 | %{UpdSprite $_}
	rts


sprypos:	.byte 	70,60,50,40,30,20,10,0
sprxpos:	.byte 	70,60,50,40,30,20,10,0
tabd010or:	.byte 	0,1,0,2,0,4,0,8,0,16,0,32,0,64,0,128
tabd010and:	.byte	$fe,$fd,$fb,$f7,$ef,$df,$bf,$7f

sineTabX:
	$sinAmp = 40*8-24
	$sinStart = 24
	$sinLen = 256
	$sinOffset = $sinLen-$sinLen/4
XDataLo:	.fill $sinLen {<($sinStart+[math]::round($sinAmp/2+$sinAmp/2*[math]::sin((($_+$sinOffset)*360/$sinLen)*[math]::PI/180)))}
XDataHi:	.fill $sinLen {>($sinStart+[math]::round($sinAmp/2+$sinAmp/2*[math]::sin((($_+$sinOffset)*360/$sinLen)*[math]::PI/180)))}

sineTabY:
	$sinAmp = 25*8-21
	$sinStart = 51-1
	$sinLen = 256
	$sinOffset = $sinLen-$sinLen/4
YDataLo:	.fill $sinLen {<($sinStart+[math]::round($sinAmp/2+$sinAmp/2*[math]::sin((($_+$sinOffset)*360/$sinLen)*[math]::PI/180)))}

function GetMCByte($img, $xb, $yb, $bgcolor, $spmc0, $spcol, $spmc1) {
	$mcb = 0

	for($i=0;$i -lt 8;$i+=2) {
		$p = $img.GetPixel($xb*8+$i, $yb)
		switch([convert]::ToInt32($p.Name, 16) -band 0xffffff) {
			$bgcolor	{$mcb = $mcb -bor 0b00; break}
			$spmc0		{$mcb = $mcb -bor 0b01; break}
			$spcol		{$mcb = $mcb -bor 0b10; break}
			$spmc1		{$mcb = $mcb -bor 0b11; break}
			default		{$mcb = $mcb -bor 0b10}
		}
		$mcb = $mcb -shl 2
	}
	$mcb = $mcb -shr 2
	return $mcb
}

$img = [System.Drawing.Image]::FromFile((get-item ".\Test\Ancients.png"))

$xSprites = [math]::Floor($img.Width/(3*8))
$ySprites = [math]::Ceiling($img.Height/21)

$data=@()
for($ySprite=0; $ySprite -lt $ySprites; $ySprite++) {
	for($xSprite=0; $xSprite -lt $xSprites; $xSprite++) {
		for($i=0; $i -lt (3*21); $i++) {
			if($ySprite*21 + [math]::Floor($i/3) -ge $img.Height) {
				$data += 0
			} else {
				$data += (GetMCByte $img ($xSprite*3+$i%3) ($ySprite*21+[math]::Floor($i/3)) 0x000000 0x706deb 0xffffff 0xedf171)
			}
		}
		$data += 0
	}
}

	.pc $3000
SpriteData:
	.byte	$data

