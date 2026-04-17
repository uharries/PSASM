function .text {
	[Alias('.txt','.petscii','.ascii')]
	[PSASM()] param (
		[Parameter(Mandatory)]
		$text,

		[switch]$AsPETSCII,

		[string]$InvocationFile,
		[int]$InvocationLine
	)

	[byte[]]$values = @()

	foreach ($o in $text) {
		if ($o -is [string]) {
			$o = $o.ToCharArray()
		}
		$values += $o
	}

	if($MyInvocation.InvocationName -match '.petscii') {$AsPETSCII = $true}
	if($MyInvocation.InvocationName -match '.ascii') {$AsPETSCII = $false}

	# This is rather incomplete ;-)
	if ($AsPETSCII) {
		$values = foreach ($c in $values) {
			if ($c -ge [char]'A' -and $c -le [char]'Z') {
				$c += 32
			} elseif ($c -ge [char]'a' -and $c -le [char]'z') {
				$c -= 32
			}
			$c
		}
	}

	$psasm.DataAdd($values, $InvocationFile, $InvocationLine)
}

# function .petscii { .text $args -AsPETSCII }
