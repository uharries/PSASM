.macro BasicPrgHeader2($addr=Next+2, $txt="") {
	.pc $0801
Head:
	.word	Next				// Link to next BASIC Line
	.word	1				// Line number
	.byte	$9E				// SYS
	.text	($addr).ToString()		// Textual representation of addr
	.byte	10				// End of line, making BASIC execute the SYS and ignore the rest
	.fill	10 {20}				// backspace 10 times to delete the display of the SYS call
	.ascii	$txt				// ..well it gives a syntax error upon return, but that will never happen in a demo
	.byte	0				// End of BASIC line
Next:	.word	0				// BASIC end marker
}
