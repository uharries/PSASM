function .repeat {
	[Alias('.rep')]
	[PSASM()] param (
		[int]$count,
		[scriptblock]$data
	)

	if ($count -gt 0) {
		0..($count-1) | ForEach-Object { $data.Invoke() }
	}
}
