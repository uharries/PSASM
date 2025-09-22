![logo](docs/pasm_logo.png)
# PASM
> *- An attempt at a PowerShell based assembler*

## Abstract
This project aims to develop a 6502 cross assembler using PowerShell, harnessing the full capabilities of PowerShell for developers. The assembler’s input source code is converted into PowerShell-compatible code, which is then executed to produce the final binary code. This approach enables developers to utilize the complete range of PowerShell functionalities in generating the resulting binary code.

## Features
- Standard 6502 Mnemonics
- Flexible number of assembly passes for complex scenarios
- Macro support
- Inline / infile direct PowerShell scripting support
- Anonymous labels
- '*' references
- C/C++/Java/PS style line comments and block comments


## Known Issues
...tooo many to mention, but a few to beware of:
- Due to the conversion of all comments to PowerShell comments, conflicts may arise between PowerShell line comments and the immediate addressing token `#`. For now, PS line comments `#` will only work for commenting out an entire line, while `//` will work at any position on a line. Consider that a recommendation to just stick with `//` style line comments.
- PowerShell variables with a name in the range of \$0 - \$ffff are not possible due to support for prefixing hexadecimal numbers with '\$'. This can be quite annoying for macros if you're used to using simple $a, $b, $c named argument names... sorry!
- The regex handling the mnemonics and operands needs to properly support identification of brackets ([{}]), specifically regarding pair matching and identifying if instruction is within a bracket space.
- The anonymous label references needs to be able to just interpret the last +/- sign as an operator if followed by a number, variable or symbol. Currently you need to add a whitespace if the operator is the same as the direction indicator.
- PowerShell labels maybe? `:label` used with `break label` in loops etc...
- ZeroPage adressing is always chosen, if possible. There is currently no way to force it or force absolute addressing instead. The optimization is performed in the .inst function and NOT written back to the sourceMap property. I plan to clean this up in a clever way later on and provide options to override/force addressing mode.
- Operands are silently truncated to the width of the applicable addressing mode. This means tha lda #-256 will load the value 0 to the accumulator and lda $12345 will load the value stored at address $2345 to the accumulator. I'm not sure this is desirable or not, yet...
- Numbers in binary format must be specified using the native PowerShell `0b` prefixed notation as the use of the traditional `%` operator is native PowerShell for modulus.
- Since macros are just PowerShell functions, the syntax for calling a macro is the same as for calling a PowerShell function. This may be confusing as the macro definition and the macro call differs in syntax. I may consider supporting calling a macro like: `macroname(123,addr)` rather than `macroname 123 addr`.
- Providing parameters when calling macros / directives can give some challenges, especially when doing inline arithmetic, like passing a parameter like `$var/2` will not always work depending on the situation. The solution is to either specify the parameter name before ALL parameters or just add parenthesis around all arguments like: `makeTab ($width/2*3) (memAddress)`. Not ideal, and yet another reason to create a wrapper for the function calls.


## Some Design Choices
Since I am trying to retrofit 6502 assembly onto the PowerShell engine, there are some inherent limitations and design choices.
- Symbols, as in references to labels, are only supported in the assembler context, meaning they are only handled as part of PASM functions and assembler instructions. If symbols, which have no identifying markers really, were to be supported throughout the entire PowerShell scope, then they would need to be checked for clashing against all PowerShell built-in functions and functions from loaded modules, aliases and reserved words. If you do need to refer to a symbol outside the assembler context, use: `$__SYM_<symbol>`. NB: maybe the `__SYM_` prefix could be dropped in the future.


## Building / Installing
There is no fancy installer yet, nor is it available on PowerShell Gallery, so you have to clone the repo and run the build script `PASM.Build.ps1`.
I may be using new features of PowerShell, so make sure to install the latest version, see: https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows?view=powershell-7.5
Short version:
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

            .word   $1234,65536,$feed

### .text
Define text data. Must be followed by a sequence of strings or byte ranged expressions.

Syntax: `.text <string|byte>[,...] [-AsPETSCII]`

Example:

            .text   "Hello World!",0

### .ascii
Alias for `.text -AsPETSCII:$false` - See `.text`

### .petcii
Alias for `.text -AsPETSCII` - See `.text`

### .org
Start a section of absolute code. The command is followed by a constant expression that gives the new PC counter location for which the code is assembled.

Example:

            .org    $7FF            ; Emit code starting at $7FF

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
See the > & < operators.


## Labels
Labels are defined as text with an immediately following ':' and can be placed anywhere[^1] in the code.
The label itself can be comprised of letters, numbers and '_' and cannot start with `$`, `.` or `-`.
Anonymous labels are supported and can be defined with a simple ':' not preceeded by a label text.
Referencing anonymous labels can be done with :+ or :- where additional +/- signs are added to refer to instances of anonymous labels further away.

Example:
```
Flickerydo:
	sei
:	lda	#0
	sta	$d021
:	lda	:#0
	sta	$d020
	inc	:-
	bne	:--
	dec	:--- +1
	jmp	:---
```
[^1]: Anywhere sensical for the assembler pc, that is. So specifically between a mnemonic and it's operand for the purpose of facilitating self-modifying code a little easier.

## Special Operators
### >
Using the > sign allows you to specify only to use the high byte of a word sized operand.

Example:
```
	lda	#>screen
```
This will load the high 8 bits of the 16 bit value *screen* into the accumulator.

### <
Using the < sign allows you to specify only to use the low byte of a word sized operand.

Example:
```
	lda	#<screen
```
This will load the low 8 bits of the 16 bit value *screen* into the accumulator.

