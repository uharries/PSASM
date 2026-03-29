function .repeat {
	[Alias('.rep')]
	[PASM()] param (
		[int]$count,
		[scriptblock]$data
	)

	if ($count -gt 0) {
		0..($count-1) | ForEach-Object { $data.Invoke() }
	}
}
