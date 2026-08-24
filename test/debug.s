hest:class abc {
	hidden abc() {}

	static [abc] Method() {
		return [abc]::new()
	}
}

	jsr	abc.lab

abc: {
	lab: {
		nop
		rts
	}
}
