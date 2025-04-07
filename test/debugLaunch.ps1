. .\build_dev.ps1

$res = 'nop' | Invoke-Assembler -NoHostOutput
# $res = 'lab: lda lab; lda #:$ff; inc :-;rts' | Invoke-Assembler -NoHostOutput
# $res = '.text "ABCabc",0 -AsPETSCII:$false' | Invoke-Assembler -NoHostOutput
# $res = Invoke-Assembler -SourceFile ".\test\demo.s" -NoHostOutput
# $res = Invoke-Assembler -SourceFile ".\test\debug.s" -NoHostOutput


Write-Host "AssemblyList:" -ForegroundColor Yellow
Write-Host "$($res.AssemblyList)"
Write-Host "BinaryList:" -ForegroundColor Yellow
Write-Host "$($res.BinaryList)"

Write-Host -ForegroundColor Cyan "`n`nℹ️  Examine the variable `$res for the captured result!`n"

