.macro mac($pa,$pb) {
	lda #1
	.macro mac() {
		lda #2
	}
	nop
	.macro mac2() {
		lda #3
		mac()
	}
	mac2()
}

mac(1,2)
