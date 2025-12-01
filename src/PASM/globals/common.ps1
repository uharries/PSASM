
$Chars0to9 = [char[]]('0','1','2','3','4','5','6','7','8','9')
$CharsAtoZ = [char[]]('A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P','Q','R','S','T','U','V','W','X','Y','Z')
$Char_ = [char[]]'_'
$CharsBin = [char[]]('0','1')
$CharsDec = [char[]]('0','1','2','3','4','5','6','7','8','9')
$CharsHex = [char[]]('0','1','2','3','4','5','6','7','8','9','A','B','C','D','E','F')
$CharsIdentifier = [char[]]($Chars0to9 + $CharsAtoZ + $Char_)

$PSKeywords = ("begin","break","catch","class","clean","continue","data","define","do","dynamicparam","else","elseif","end","enum","exit","filter","finally","for","foreach","from","function","hidden","if","in","param","process","return","static","switch","throw","trap","try","until","using","var","while")

### Use this to generate / update the list as new functions / directives are added:
### "`$PASMFunctions = (`"$((Get-PASMFunction).Name -join '", "')`")"
$PASMFunctions = (".ascii", ".hi", ".lab", ".lo", ".mac", ".petscii", ".rep", ".txt", "dc.b", "dc.w", ".align", ".byte", ".fill", ".include", ".includeonce", ".inst", ".label", ".macro", ".org", ".pc", ".repeat", ".text", ".word", "_getSymbol", "_hiByte", "_invokeMacro", "_loByte")
