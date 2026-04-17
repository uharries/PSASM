function .align {
	[PSASM()] param (
		[ValidateRange(1,[int]::MaxValue)]
		[int]$Boundary,
		[int]$FillByte = 0x00,
		[string]$InvocationFile,
		[int]$InvocationLine
	)
	.fill (([math]::Ceiling((.pc) / $boundary) * $boundary) - (.pc)) {$fillByte} -InvocationFile $InvocationFile -InvocationLine $InvocationLine
}
