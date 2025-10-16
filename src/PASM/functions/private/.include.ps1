function .include {
	[Alias('.inc')]
	[PASM()] param (
		[string]$file
	)

	$path = (Resolve-Path $file).Path

	$content = Get-Content $path -Raw

}
