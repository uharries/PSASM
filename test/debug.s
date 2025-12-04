
	SCREEN = $0400

	.segment	"code" -Start $1000
	.segment	"data" -Start $1100
	.segment	"code"
	zp = &{
		.pushsegment	"zeropage" -Start $02 -Virtual
		Lab1:	.byte	$f1,$f2,$f3
		.popsegment
	}
	nop
	lda	zp.Lab1

	.segment	"data"

	.byte	$ab,$cd,$ef

	.segment	"code"

	lda	#$ae
	sta	SCREEN

	.segment	"code2" -Start $1080 -Run $8000
:
	lda	#>:-
	sta :+
	bne :-
:
	.byte	$12,$34,$56
