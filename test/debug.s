.macro hest(){nop;lab:};hest;lda hest.lab
0..1 | %{lda lab;};lab:

.macro mac($addr=mac.end) {lda $addr; end:}; mac



.macro mac2 {
lab:
	lda	:+
:
}
	lda mac.end
	lda mac2.lab
	mac2
	mac2
	mac2
