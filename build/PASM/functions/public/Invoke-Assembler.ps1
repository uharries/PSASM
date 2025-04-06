
<#
	.SYNOPSIS
	Assembles 6502 assembler instructions to a C64 compatible .PRG file.

	.DESCRIPTION
	Assembles 6502 assembler instructions to a C64 compatible .PRG file.
	Supports the standard 6502 mnemonics mixed with PowerShell for optional code generating logic.
	For a list of supported assembler directives, look elsewhere...

	.PARAMETER SourceFile
	Specifies the name of the source file to assemble.

	.PARAMETER OutFile
	Specifies the name of the file the binary code is written to.

	.PARAMETER DumpPSFile
	Specifies the name of the file the intermediate PowerShell code is written to.
	This is mostly useful for debugging the Assembler itself.

	.PARAMETER ListAssembly
	Prints the assembler listing to the screen, if specified.

	.PARAMETER ListBinary
	Prints a Hex Dump of the binary code produced by the assembler to the screen.

	.PARAMETER Source
	Specifies an Array if strings to process as the source code.

	.INPUTS
	An array of strings to process as the assembler source code.

	.OUTPUTS
	An Assemblerinformation object containing the properties: Success, LoadAddress, Symbols, PSSource, SourceMap, Assembly, AssemblyList, Binary, BinaryList, and BinaryHash.

	.EXAMPLE
	PS> $rc = Invoke-Assembler -SourceFile demo.s -OutFile demo.prg
	Pass 1... OK! - Hash: 7554E67721301AD0A4CDDA94ACA9FEC8A64A9F25A2431CF83616AE9DC619469C
	Pass 2... OK! - Hash: 7554E67721301AD0A4CDDA94ACA9FEC8A64A9F25A2431CF83616AE9DC619469C

	Writing 'demo.prg'...File Hash: 7554E67721301AD0A4CDDA94ACA9FEC8A64A9F25A2431CF83616AE9DC619469C

	.EXAMPLE
	PS> '.org $1000; inc $d020; jmp *-3' | Invoke-Assembler -OutFile demo.prg
	Pass 1... OK! - Hash: 7554E67721301AD0A4CDDA94ACA9FEC8A64A9F25A2431CF83616AE9DC619469C
	Pass 2... OK! - Hash: 7554E67721301AD0A4CDDA94ACA9FEC8A64A9F25A2431CF83616AE9DC619469C

	Writing 'demo.prg'...File Hash: 7554E67721301AD0A4CDDA94ACA9FEC8A64A9F25A2431CF83616AE9DC619469C

	Success      : True
	LoadAddress  : 4096
	Symbols      : {[____load_addr, System.Collections.Hashtable]}
	PSSource     : .org 0x1000;.inst inc Absolute (0xd020)
	SourceMap    : {SourceMapLine, SourceMapLine}
	Assembly     : {}
	AssemblyList : $1000: ee 20 d0 - Ln: 1   Col: 13  - .org 0x1000;inc 0xd020;jmp  ($pasm.pc) -3 - .org 0x1000;.inst inc
				Absolute (0xd020)

	Binary       : {0, 16, 238, 32…}
	BinaryList   : $0000: 00 10 ee 20 d0                                    '... .'

	BinaryHash   : 7554E67721301AD0A4CDDA94ACA9FEC8A64A9F25A2431CF83616AE9DC619469C

#>
function Invoke-Assembler {
	[CmdletBinding()]
	param (
		[Parameter()]
		[Alias("I","Input")]
		[string]$SourceFile,

		[Parameter()]
		[Alias("O","Output")]
		[string]$OutFile,

		[Alias("ps","psfile")]
		[string]$DumpPSfile,

		[Alias("l","list")]
		[switch]$ListAssembly,

		[Alias("h","hexdump","DumpHex","dump","hex")]
		[switch]$ListBinary,

		[Alias("q")]
		[switch]$NoHostOutput,

		[Parameter(ValueFromPipeline)]
		[string[]]$Source
	)


	BEGIN {
		$ErrorActionPreference = 'Stop'
		[string[]]$asmSource = @()
	}

	PROCESS {
		if ($SourceFile) {
			$Source = Get-Content -Path $SourceFile
		}
		if ($Source) {
			$asmSource += $Source
		}
	}

	END {
		$pasm = [PASM]::new($asmSource -join "`n", $NoHostOutput)
		$pasm.Parse()

		if ($DumpPSfile) {
			$pasm.workSource | set-content -path $DumpPSfile -Force
		}

		$asmInfo = $pasm.Assemble()

		if ($ListAssembly) {
			if (-not $NoHostOutput) {
				Write-Host "`nListing Assembly:`n"
				Write-Host $asmInfo.AssemblyList
			}
		}

		if ($ListBinary -or !$OutFile) {
			if (-not $NoHostOutput) {
				Write-Host "`nListing Binary:`n"
				Write-Host $asmInfo.BinaryList
			}
		}

		if ($OutFile) {
			if (-not $NoHostOutput) {
				Write-Host ("`nWriting '$OutFile'...") -NoNewline
			}
			$asmInfo.Binary | set-content -asbytestream -path $OutFile
			if (-not $NoHostOutput) {
				Write-Host ("File Hash: {0:x}" -f ((Get-FileHash -Algorithm SHA256 $OutFile).Hash))
			}
		}

		return ($asmInfo)
	}
}

