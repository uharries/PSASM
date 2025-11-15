
$setBorder1 = {
	param($color)
	lda	#$color
	sta	$d021
	.macro mac1() {
		lda #1
	}
}

setBorder2 = {
	param($color)
	lda	#$color
	sta	$d022
	.macro mac2() {
		lda #2
	}
}

setBorder3 = &{
	param($color)
	lda	#$color
	sta	$d023
	.macro mac3() {
		lda #3
	}
}

class setBorder4 {
	static mac4() {
		lda #4
	}
}

class setBorder5 {
	$BorderColor = 5
	$data = $(
		$pc = (.pc)
		.pc $0020
		;SomeData:;
			.byte	5
		.pc $pc
	)

	setBorder5() {

	}

	mac5() {
		lda #5
	}
	setBorder() {
		lda	#$this.BorderColor
		sta	$d020
		lda	$this.data.SomeData
	}
}



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

// mac(1,2)

&$setBorder1 1

// will throw: Symbol 'setBorder2.mac2' in scope '3:setBorder2' is not a macro or not yet instantiated
//setBorder2.mac2

&setBorder2 2

[setBorder4]::mac4()

$sb5 = [setBorder5]::new()
$sb5.mac5()
$sb5.setBorder()

