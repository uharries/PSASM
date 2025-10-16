
.macro mac(){
	nop
}

.macro mac2() {
	mac
}

	lda	#$23
	mac2()
	rts
