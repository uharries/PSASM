. .\build_dev.ps1 -debug

$res = Invoke-Assembler -SourceFile ".\test\debug.s" -LabelFile ".\test\debug.lbl" -DumpPSfile ".\test\debug.ps1" #-NoHostOutput

Write-Host -ForegroundColor Cyan "`n`nℹ️  Examine the variable `$res for the captured result!`n"
