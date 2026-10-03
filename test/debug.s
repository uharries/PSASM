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


:	inc	$0400
	bne :-


.align 256
.byte 1,2,3,4
.fill 5 {$ea}

.pushsegment Code -Start $1000
text: .text "ABCabc",0
.popsegment
nop
