. .\build_dev.ps1 -debug

$res = Invoke-Assembler -SourceFile ".\test\debug.s" #-NoHostOutput

Write-Host -ForegroundColor Cyan "`n`nℹ️  Examine the variable `$res for the captured result!`n"
