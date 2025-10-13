function .fill {
	[PASM()] param ([ValidateRange(1,[int]::MaxValue)][int]$count,[scriptblock]$data)
	.byte (0..($count-1) | ForEach-Object $data)
}
