function .fill {
	[PASM()] param (
		[ValidateRange(1,[int]::MaxValue)]
		[int]$count,
		[scriptblock]$data,
		[string]$InvocationFile,
		[int]$InvocationLine
	)
	.byte -Values (0..($count-1) | ForEach-Object $data) -InvocationFile $InvocationFile -InvocationLine $InvocationLine
}
