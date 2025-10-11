.macro BasicPrgHeader($Address=BasicPrgHeader.end, $BasicLineNumber=(Get-Date).Year) {
	.pc $0801
	.word	:+, 1				// Link to next BASIC Line
	.text	$9e, ($Address).ToString(), 0	// SYS, Textual representation of addr, end of BASIC line
:	.word	0				// BASIC end marker
end:
}
