function .repeat {
	[Alias('.rep')]
	[PASM()] param (
		[int]$count,
		[scriptblock]$data
	)

	0..($count-1) | ForEach-Object { $data.Invoke() }

}
