. .\build_dev.ps1 -debug

# $res = Invoke-Assembler -SourceFile ".\test\SpriteDemo.s" -OutFile .\output\SpriteDemo.prg
# $res = 'nop' | Invoke-Assembler -ListAssembly -ListBinary
# $res = 'lab: lda lab; lda #:$ff; inc :-;rts' | Invoke-Assembler -NoHostOutput
# $res = '.text "ABCabc",0 -AsPETSCII:$false' | Invoke-Assembler -NoHostOutput
# $res = Invoke-Assembler -SourceFile ".\test\demo.s" -NoHostOutput
# $res = 'jmp*' | Invoke-Assembler -ListAssembly -ListBinary
New-PSDrive -Name Tmp -PSProvider FileSystem -Root D:\Temp\
$res = Invoke-Assembler -SourceFile "Tmp:\testC.s" -ListAssembly -ListBinary
# $res = '.include ".\test\asm1.s"' | Invoke-Assembler -ListAssembly -ListBinary
# $res = '.byte $de,$ad' | Invoke-Assembler -ListAssembly -ListBinary

# Write-Host "AssemblyList:" -ForegroundColor Yellow
# Write-Host "$($res.AssemblyList)"
# Write-Host "BinaryList:" -ForegroundColor Yellow
# Write-Host "$($res.BinaryList)"

Write-Host -ForegroundColor Cyan "`n`nℹ️  Examine the variable `$res for the captured result!`n"

