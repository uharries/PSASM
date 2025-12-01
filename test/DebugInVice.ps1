$res = Invoke-Assembler .\test\SpriteDemo2.s -OutFile .\output\SpriteDemo2.prg

$vicePath = "C:\Users\ulf\OneDrive\Tools\Vice\bin\x64sc.exe"

$prgFile = ".\output\SpriteDemo2.prg"
$labelFile = ".\test\SpriteDemo2.lbl"
$moncommandsFile = ".\test\moncommands.txt"
$labels = gc -Path $labelFile

foreach ($l in $labels) {
	if ($l -match '([0-9a-f]+)\s\.breakpoint') {
		$breakpoints += "break {0}`n" -f $Matches[1]
	}
}

$moncommands = "ll `"$labelFile`"`n"
$moncommands += $breakpoints

$moncommands | Set-Content -path $moncommandsFile -Force

& $vicePath -moncommands $moncommandsFile -autostart $prgFile
return $res
