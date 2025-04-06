# The Book of Random Ideas

### Operation...
- Remove

### Scopes
- Unnamed Scopes
- Names Scopes

#### Unnamed Scopes
Create them as ScriptBlocks?

#### Named Scopes
Create them as classes?
```
class MyProc {
lab:    lda #$00
        rts
}
```
translates to:
```
class MyProc {
.label lab ;   .inst lda Immediate (0x00)
        .inst rts Implied
}
```
So to acces the inside of MyProc, you'd ...???  symbols exist outside of PS logic...

## Macros
Could be implemented as parametized ScriptBlocks?
Need a .macro function for the user to define the macro.
Need the .macro function to define a new function with the macro name...

So a definition like:
```
.macro mov (param1, param2) {
    lda #$param1
    sta $param2
}
```
Could be translated to:
```
Invoke-Command -ScriptBlock {
    param($param1,$param2)
    lda #$param1
    sta $param2
} -ArgumentList $param1, $param2
```
By implementing:
```
function .macro {
    param([string]$name, [string[]]$params, [ScriptBlock]$code)
    function script:$name {
        param($params)
        Invoke-Command -ScriptBlock $code -ArgumentList @params
    }
}
```
or, if I it was allowed, simply set-alias .macro function
...but it isn't :(
so I for now ended up with a simple regex replace .macro for function ;-)
That allow me to write macros like:
```
.macro WaitScanline($line) {
	lda	#<($line)
ll:	cmp	$d012
	bne	ll
	bit	$d011
	if ($line -le 255) {
		bmi	ll
	} else {
		bpl	ll
	}
}
```
If the macro is not invoked, the symbol resove check fails, since the label references get picked up, but the label never actually defined/resolved.


