. .\build_dev.ps1

$res = Invoke-Assembler -SourceFile ".\test\SpriteDemo.s" -OutFile .\output\SpriteDemo.prg
# $res = 'nop' | Invoke-Assembler -ListAssembly -ListBinary
# $res = 'lab: lda lab; lda #:$ff; inc :-;rts' | Invoke-Assembler -NoHostOutput
# $res = '.text "ABCabc",0 -AsPETSCII:$false' | Invoke-Assembler -NoHostOutput
# $res = Invoke-Assembler -SourceFile ".\test\demo.s" -NoHostOutput
# $res = Invoke-Assembler -SourceFile ".\test\debug.s" -NoHostOutput
# $res = 'jmp*' | Invoke-Assembler -ListAssembly -ListBinary

# Write-Host "AssemblyList:" -ForegroundColor Yellow
# Write-Host "$($res.AssemblyList)"
# Write-Host "BinaryList:" -ForegroundColor Yellow
# Write-Host "$($res.BinaryList)"

Write-Host -ForegroundColor Cyan "`n`nℹ️  Examine the variable `$res for the captured result!`n"

