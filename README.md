![logo](docs/pasm_logo.png)
# PASM - The PowerShell 6502 Assembler
> *PASM is a PowerShell-based assembler for 6502/6510-based platforms, created by Ulf Diabelez Harries*

## Abstract
This project aims to develop a 6502 cross assembler using PowerShell, harnessing the full capabilities of PowerShell for developers. The assembler’s input source code is converted into PowerShell-compatible code, which is then executed to produce the final binary code. This approach enables developers to utilize the complete range of PowerShell functionalities in generating the resulting binary code.

## Features
- Standard 6502 Mnemonics
- Flexible number of assembly passes for complex scenarios
- Macro support
- Namespace support
- Class support
- Inline / infile direct PowerShell scripting support
- Anonymous labels
- '*' references
- C/C++/Java/PS style line comments and block comments
- and many, many more...

## Known Issues
...tooo many to mention, but a few to beware of:
- PowerShell variables with a name in the range of `$0 - $ffff` are not possible due to support for prefixing hexadecimal numbers with `$`. This can be quite annoying for macros if you're used to using simple `$a`, `$b`, `$c` named argument names... sorry!
- PowerShell labels `:label` used with `break :label` in loops is not currently supported.
- ZeroPage adressing is always chosen, if possible. There is currently no way to force it or force absolute addressing instead.
- Operands are silently truncated to the width of the applicable addressing mode. This means that e.g. `lda #-256` will load the value `0` to the accumulator and `lda $12345` will load the value stored at address `$2345` to the accumulator.
- Doing inline arithmetic like `$var/2+3` is of course fully supported, but follows PowerShell parsing rules and restrictions, which in short means that you are in many cases forced to enclose the expression in parenthesis.

## Some Design Choices
Since I am trying to retrofit 6502 assembly onto the PowerShell engine, there are some inherent limitations and design choices.
- Symbols, which have no identifying markers really, are supported in many PowerShell contexts, but not checked against all possible conflicts. Currently you can define labels that conflict with PowerShell or the assembler itself, but you cannot refer to them if they are a PowerShell keyword, an assembler directive or an assembler mnemonic. As symbols may change values between passes, special care needs to be taken when used outside of instructions and directives.
- To support traditional 6502 coding conventions, hexadecimal numbers can be specified with the prefix `$` as well as PowerShell's native `0x` prefix. This creates a conflict with PowerShell variables named in the hexadecimal range of `$0000 - $ffff`, where any potential variable you may define, like e.g. `$c64`, `$c0` etc. will be treated as the hexadecimal numbers instead of PowerShell variables.
- Similarly the binary notation prefix `%`is allowed in addition to PowerShell's native `0b` prefix, however there are no known limitations as a result of this.

## Building / Installing
There is no fancy installer yet, nor is it available on PowerShell Gallery, so you have to clone the repo and run the build script `build_release.ps1`.
I may be using new features of PowerShell, so make sure to install the latest version, see: https://learn.microsoft.com/en-us/powershell/scripting/install/install-powershell?view=powershell-7.6

Short version for Windows users:
- `winget install --id Microsoft.PowerShell --source winget`

The build script requires Pester version 5 or greater, so make sure to install that first.
You can install the latest version of Pester by running:

- `Install-Module -Name Pester`

After reloading your PowerShell environment, the build script will make use of the latest Pester module and upon completion, the module will be imported and ready to use.

If you want to use it in another PowerShell session, you can manually import it by running:

- `Import-Module <repo path>\build\PASM.psm1`

## Running the Assembler
In order to assemble your very first C64 prg file, you run the command: Invoke-Assembler.

In it's simplest form, it could look something like this:

```
PS> $rc = Invoke-Assembler -SourceFile demo.s -OutFile demo.prg
	Pass 1... OK! - Hash: 7554E67721301AD0A4CDDA94ACA9FEC8A64A9F25A2431CF83616AE9DC619469C
	Pass 2... OK! - Hash: 7554E67721301AD0A4CDDA94ACA9FEC8A64A9F25A2431CF83616AE9DC619469C

	Writing 'demo.prg'...File Hash: 7554E67721301AD0A4CDDA94ACA9FEC8A64A9F25A2431CF83616AE9DC619469C
```

This would render a .PRG file from your 1337 demo.s source code.

Invoke-Assembler will also take your source code from the pipeline:
```
	PS> '.org $1000; inc $d020; jmp *-3' | Invoke-Assembler -OutFile demo.prg
	Pass 1... OK! - Hash: D072F0ECF7AA1BEC474BB499EA973111779E74FEB141ABA18C1E10B20E90DF4A
	Pass 2... OK! - Hash: D072F0ECF7AA1BEC474BB499EA973111779E74FEB141ABA18C1E10B20E90DF4A

	Writing 'demo.prg'...File Hash: D072F0ECF7AA1BEC474BB499EA973111779E74FEB141ABA18C1E10B20E90DF4A

	Success      : True
	LoadAddress  : 4096
	Symbols      : {[____load_addr, System.Collections.Hashtable]}
	PSSource     : .org 0x1000; .inst -Mnemonic inc -AddressingMode Absolute -Opera...
	SourceMap    : {System.Collections.Hashtable}
	Assembly     : {, }
	AssemblyList : $1000: ee 20 d0 - Ln: 1   Col: 14  - .org $1000 - .org 0x1000; ....
	Binary       : {0, 16, 238, 32…}
	BinaryList   : $0000: 00 10 ee 20 d0 4c 00 10                           '... .L..'

	BinaryHash   : D072F0ECF7AA1BEC474BB499EA973111779E74FEB141ABA18C1E10B20E90DF4A
```
And as the output was not assigned to a variable, it got dumped to stdout, so you can see the properties and type of data that is available from the returned `AssemblerInformation` object.

## Assembler Directives

### .byte
Define byte sized data. Must be followed by a sequence of 8 bit byte ranged expressions.

Example:

            .byte   $12,$34,255

### .word
Define word sized data. Must be followed by a sequence of 16 bit word ranged expressions.

Example:

            .word   $1234,65535,$feed

### .text
Define text data. Must be followed by a sequence of strings or byte ranged expressions.

Syntax: `.text <string|byte>[,...] [-AsPETSCII]`

Example:

            .text   "Hello World!",0

### .ascii
Alias for `.text -AsPETSCII:$false` - See `.text`

### .petscii
Alias for `.text -AsPETSCII` - See `.text`

### .org
Start a section of absolute code. The command is followed by a constant expression that gives the new PC counter location for which the code is assembled.

Example:

            .org    $7FF            // Emit code starting at $7FF

### .macro
Defines a macro.

Syntax: `.macro <macro name> ( $param1, $param2, ... ) { <code block> }`

Example:
```
.macro WaitScanline($line) {
	lda	#<($line)
:	cmp	$d012
	bne	:-
	bit	$d011
	if ($line -le 255) {
		bmi	:-
	} else {
		bpl	:-
	}
}
```

### .hi .hibyte .lo .lobyte
See the `>` & `<` operators.


## Labels
Labels are defined as text with an immediately following `:` and can be placed anywhere[^1] in the code.
The label itself can be comprised of letters `a-z`, numbers and `_`, but cannot start with a number.
Anonymous labels are supported and can be defined with a simple `:` not preceeded by a label text.
Referencing anonymous labels can be done with `:+` or `:-` where additional `+`/`-` signs are added to refer to instances of anonymous labels further away.

Example:
```
Flickerydo:
	sei
:               // <--------------------------------------+
	lda	#0      // <-----------------------------------+  |
	sta	$d021   //                                     |  |
:               // <--------------------------------+  |  |
	lda	:#0     // <-----------------------------+  |  |  |
	sta	$d020   //                               |  |  |  |
	inc	:-      // Increase the operand value ---+  |  |  |
	bne	:--     // Branch two labels back ----------+  |  |
	dec	:---+1  // Decrease the operand to lda --------+  |
	jmp	:---    // jump three labels back ----------------+
```
[^1]: Anywhere sensical for the assembler pc, that is. So specifically between a mnemonic and it's operand for the purpose of facilitating self-modifying code a little easier.

## Special Operators
### >
Using the `>` sign allows you to specify only to use the high byte of a word sized operand.

Example:
```
	lda	#>screen
```
This will load the high 8 bits of the 16 bit value *screen* into the accumulator.

### <
Using the `<` sign allows you to specify only to use the low byte of a word sized operand.

Example:
```
	lda	#<screen
```
This will load the low 8 bits of the 16 bit value *screen* into the accumulator.


# Segments

Segments are named memory regions that control where your code and data end up in the final binary. If you've used linkers like ld65, the concept is similar — but in PASM, segments are defined and switched inline with your code rather than in a separate linker configuration file.

---

## The Default Segment

When you start assembling without defining any segments, your code goes into the **default segment**, which starts at address `$0000` and has no size limit. It allows overlap, so other segments can freely be placed on top of it.

---

## Defining and Switching Segments

```asm
.segment "name" [options]
```

The first time you reference a segment name it is created with the options you provide. Subsequent references to the same name simply switch the assembler's output to that segment — any options you repeat are silently ignored. This means you can freely interleave code between segments across your source file:

```asm
.segment code -Start $1000
    lda #1          // goes into 'code'

.segment data -Start $2000
    .byte $FF       // goes into 'data'

.segment code       // switch back to 'code', -Start $1000 would be ignored here
    lda #2          // continues where 'code' left off
```

The final binary is laid out by address, not by the order segments were written. So the example above produces a binary with `code` at `$1000` and `data` at `$2000` regardless of which was defined first.

---

## Placement

### Fixed Start Address

```asm
.segment code -Start $1000
```

Places the segment at an explicit address. This is the most common case.

### Chaining with StartAfter

```asm
.segment header -Start $0801
    // ... BASIC stub ...
.segment code -StartAfter header
    // starts immediately after header ends
```

`-StartAfter` places the segment immediately after another segment ends. The start address is resolved automatically once the referenced segment's size is known. This is useful for building contiguous memory layouts without hardcoding addresses.

### Bounding the Segment

You can constrain a segment's size using `-End`, `-Size`, or both together with `-Start`. Any two of the three imply the third:

| Parameters | Effect |
|---|---|
| `-Start` `-End` | Size is derived |
| `-Start` `-Size` | End is derived |
| `-End` `-Size` | Start is derived |
| `-Start` `-End` `-Size` | Error — overdetermined |
| `-Start` `-StartAfter` | Error — contradictory |

```asm
.segment main  -Start $0900 -End $09FF   // 256 byte region
.segment buf   -Start $0200 -Size 256    // same, written differently
.segment extra -End $0BFF   -Size 16     // 16 bytes ending at $0BFF
```

If a segment's content grows beyond its defined bounds, the assembler throws an error.

---

## Load vs. Run Address

Sometimes code needs to be stored at one address (the load address, where it lives in the binary) but execute from another (the run address, where it will be copied to before running). The `-Run` parameter handles this:

```asm
.segment fastcode -Start $C000 -Run $0300
    lab: lda lab    // 'lab' resolves to $0300 (run address)
                    // but bytes are placed at $C000 in the binary
```

All labels and the program counter (`*`) within the segment reflect the run address. The binary placement uses the load address. Without `-Run`, the run address equals the load address.

---

## Fill

By default, any gaps within a segment are left as zero. The `-Fill` switch causes the entire region to be padded with a repeating byte pattern, written before your code and data so your content always takes priority:

```asm
.segment main -Start $1000 -End $1FFF -Fill -FillBytes $FF
```

`-FillBytes` accepts a comma-separated list of bytes that repeat across the filled region:

```asm
.segment main -Start $1000 -End $1005 -Fill -FillBytes $AA,$BB
// produces: $AA,$BB,$AA,$BB,$AA,$BB (then your code on top)
```

If `-FillBytes` is omitted, the fill byte defaults to `$00`.

---

## Alignment

### Positive Alignment

Rounds the segment's start address up to the nearest multiple of the alignment value:

```asm
.segment code -Start $1001 -Align 256   // actually starts at $1100
.segment code -Start $1001 -Align 4     // actually starts at $1004
.segment code -Start $1000 -Align 4     // already aligned, no change
```

Without `-Fill`, alignment moves the segment start forward and the skipped bytes are not part of the segment. Combined with `-Fill`, the gap between the specified start and the aligned start is padded:

```asm
.segment code -Start $1001 -End $1007 -Align 4 -Fill
// fill covers $1001..$1003, content starts at $1004
```

### Negative Alignment

Anchors your content to an alignment boundary near the *end* of the region, filling the space before it. Negative alignment always implies `-Fill`.

```asm
.segment code -End $100F -Align -8
    lda #1      // content is placed at the last 8-byte boundary before $100F
                // everything before it is filled with $00
```

With an explicit `-Start`, the fill covers the full range from start to end:

```asm
.segment code -Start $1000 -End $100F -Align -8 -FillBytes $EA
    lda #1
// $1000..$1007: $EA $EA $EA $EA $EA $EA $EA $EA  (fill)
// $1008:        $A9 $01                           (lda #1)
// $100A..$100F: $EA $EA $EA $EA $EA $EA           (fill)
```

Negative alignment requires `-End` (or `-Start` with `-Size`) so the assembler knows where the region ends.

---

## Virtual Segments

A virtual segment tracks addresses and advances the program counter but emits no bytes into the binary. This is useful for describing RAM layouts so labels resolve to the right addresses, without generating any output:

```asm
.segment zeropage -Start $00 -Virtual
    zpTemp:  .fill 2 { 0 }   // reserve 2 bytes — no output
    zpCount: .fill 1 { 0 }   // reserve 1 byte  — no output

.segment code -Start $1000
    lda zpTemp      // resolves correctly to $0000
    ldx zpCount     // resolves correctly to $0002
```

Segments that use `-StartAfter` a virtual segment are still placed correctly after it, since the virtual segment's size is tracked even though it produces no bytes.

---

## Overlapping Segments

By default the assembler throws an error if two segments occupy the same address range. Use `-AllowOverlap` on a segment to permit other segments to overlap it.

A practical use case is patching: define a segment covering a region of memory, mark it as allowing overlap, then define a smaller patch segment that overwrites part of it:

```asm
.segment base -Start $1000 -Size 16 -Fill -FillBytes $EA -AllowOverlap
    // 16 NOPs as a base

.segment patch -Start $1004
    lda #$FF    // overwrites bytes at $1004..$1006
```

`-AllowOverlap` is set on the segment that *permits itself to be overlapped*, not on the segment doing the overlapping. In the example above `base` opts in, so `patch` can write on top of it without error.

---

## Saving and Restoring the Current Segment

`.pushsegment` and `.popsegment` let you temporarily switch to another segment and return to where you were. `.pushsegment` accepts the same options as `.segment`:

```asm
.segment code -Start $1000
    lda #<data_table

.pushsegment rodata -Start $2000
    data_table: .byte 1,2,3,4
.popsegment

    lda #>data_table    // back in 'code', right where we left off
```

Pushes and pops can be nested to any depth.

---

## Quick Reference

| Parameter | Description |
|---|---|
| `-Start $addr` | Load address of segment |
| `-End $addr` | Last address of segment (inclusive) |
| `-Size n` | Size of segment in bytes |
| `-StartAfter name` | Place immediately after named segment ends |
| `-Run $addr` | Run/execute address when different from load address |
| `-Align n` | Positive: align start forward to boundary. Negative: anchor content from end |
| `-Fill` | Pad entire region with fill pattern |
| `-FillBytes $b1,$b2,...` | Repeating fill pattern (default `$00`) |
| `-AllowOverlap` | Permit other segments to overlap this one |
| `-Virtual` | Track addresses but emit no bytes |


## Advanced Use Cases
### Using Named Scopes to Create Runtime Objects
You can define named scopes with code and labels and place code and data in different memory segments like this:
(this is a bad example, I need to update with something that better shows the actual possibilities...)
```
	.segment "CODE" -Start $1000			// Define a "CODE" segment that starts at memory address $1000
	.segment "DATA" -Start $2000			// Define a "DATA" segment that starts at memory address $2000

MyObject: {									// Create a label and a scope named MyObject
	$SomeVar = 42

	.pushsegment "DATA"						// Push current segment on stack and switch to "DATA" segment

	Message:	.petscii "hello world!", 0	// Define a label and a zero terminated PETSCII message

	.popsegment								// Pop previous segment from stack

	.macro PrintMessage {					// Define a macro named PrintMessage
		ldx #0
	:	lda Message,x						// Load character from label MyObject.Message
		beq :+
		jsr $ffd2							// Print character
		inx
		bne :-
	:
	}

	.pushsegment "CODE"						// Push current segment on stack and switch to "CODE" segment

	Init: {
		PrintMessage()						// Emit the PrintMessage() macro from nearest parent scope (MyObject)
	}

	.popsegment								// Pop previous segment from stack

	Write-Host $SomeVar						// Output text to the console: 42
}


	.segment "CODE"							// Switch to segment "CODE"
Start: {									// Create a label and a scope named Start
	$SomeOtherVar = 67
	MyObject.PrintMessage()					// Emit the PrintMessage() macro from MyObject scope
	jsr MyObject.Init						// Emit the PrintMessage() macro from MyObject scope
	rts

	Write-Host $SomeVar						// Outputs an empty string to the console, as $SomeVar is not found in current or parent scopes
	Write-Host $SomeOtherVar				// Outputs the text '67' to the console
}
```
PowerShell does not provide any way to refer to PowerShell variables in sibling scopes, so if you want to access $SomeVar from different sibling scopes, you need to place the variable in a common parent scope.
