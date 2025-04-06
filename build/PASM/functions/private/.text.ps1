function .text {
	[Alias('.txt','.petscii','.ascii')]
	[PASM()] param (
		[Parameter(Mandatory)]
		$text,

		[switch]$AsPETSCII
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

	$pasm.DataAdd($values, $MyInvocation)
}

# function .petscii { .text $args -AsPETSCII }
