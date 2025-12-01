
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
		[Parameter(ValueFromPipeline)]
		[object]$InputObject,

		[Parameter()]
		[Alias("I","Input")]
		[string]$SourceFile,

		[Parameter()]
		[Alias("O","Output")]
		[string]$OutFile,

		[Parameter()]
		[Alias("lbl")]
		[string]$LabelFile = $SourceFile ? "$($SourceFile -replace '(.*)([.].*)','$1').lbl" : $null,

		[Alias("ps","psfile")]
		[string]$DumpPSfile,

		[Alias("l","list")]
		[switch]$ListAssembly,

		[Parameter()]
		[Alias("lst")]
		[string]$ListFile = $SourceFile ? "$($SourceFile -replace '(.*)([.].*)','$1').lst" : $null,

		[Alias("h","hexdump","DumpHex","dump","hex")]
		[switch]$ListBinary,

		[Alias("q")]
		[switch]$NoHostOutput,

		[switch]$Version
	)

	BEGIN {
		$ErrorActionPreference = 'Stop'
		function Print-Banner {
			$vTag = format-string -Text "Version: $($script:ModuleVersion)" -Format Center -OutputStringWidth 21
			Write-Host "                                                      "
			Write-Host '        _/_/_/      _/_/      _/_/_/  _/      _/      '
			Write-Host '       _/    _/  _/    _/  _/        _/_/  _/_/       '
			Write-Host '      _/_/_/    _/_/_/_/    _/_/    _/  _/  _/        '
			Write-Host '     _/        _/    _/        _/  _/      _/         '
			Write-Host '    _/        _/    _/  _/_/_/    _/      _/          '
			Write-Host "                                                      "
			Write-Host "      ---> The PowerShell 6502 Assembler <---         "
			Write-Host "          --> by Ulf Diabelez Harries <--             "
			Write-Host "             ->$vTag<-                "
			Write-Host "                                                      "
		}

		$SourceFiles = @()
		$SourceLines = [System.Text.StringBuilder]::new()
	}

	PROCESS {
		if ($InputObject) {
			if ($InputObject -is [System.IO.FileInfo]) {
				$SourceFiles += $InputObject
			} elseif ($InputObject -is [string]) {
				$SourceLines.AppendLine($InputObject)
			} else {
				Write-Warning -Message "Ignoring unsupported input object: $($InputObject.GetType().FullName)"
			}
		}
	}

	END {
		if (-not $NoHostOutput) {
			Print-Banner
		}

		if($Version) {
			if (-not $NoHostOutput) {
				Write-Host "`nBuilt on $script:ModuleBuildDate`n"
			}
			return [version]$script:ModuleVersion
		}

		if ($SourceLines.Length -eq 0 -and $SourceFiles.Count -eq 0 -and -not $SourceFile) {
			Write-Error "No source specified. Use -SourceFile or provide source via the pipeline."
			return $null
		}

		$pasm = [PASM]::new()
		$pasm.NoHostOutput = $NoHostOutput

		# Source and SourceFile go into a LIFO buffer, so pipeline source is processed before pipeline files, before files on command line by the assembler, if more are supplied
		if ($SourceFile) {
			$pasm.LoadFile($SourceFile)
		}
		foreach ($file in $SourceFiles) {
			$pasm.LoadFile($file)
		}
		if ($SourceLines.Length -gt 0) {
			$pasm.LoadVirtualFile("<PipeLine>", $SourceLines.ToString())
		}

		$pasm.Parse()

		if ($DumpPSfile) {
			$pasm.psSource | set-content -path $DumpPSfile -Force
		}

		$asmInfo = $pasm.Assemble()

		if ($ListFile) {
			$asmInfo.AssemblyList | set-content -path $ListFile -Force
		}

		if ($ListAssembly) {
			if (-not $NoHostOutput) {
				Write-Host "`nListing Assembly:`n"
				Write-Host $asmInfo.AssemblyList
			}
		}

		if ($ListBinary) {
			if (-not $NoHostOutput) {
				Write-Host "`nListing Binary:`n"
				Write-Host $asmInfo.BinaryList
			}
		}

		if ($OutFile) {
			if (-not $NoHostOutput) {
				Write-Host ("`nWriting '$OutFile'...") -NoNewline
			}
			if (-not(Test-Path -Path $OutFile)) {
				New-Item -Path $OutFile -Force
			}
			$asmInfo.Binary | set-content -asbytestream -path $OutFile -Force
			if (-not $NoHostOutput) {
				Write-Host ("File Hash: {0:x}" -f ((Get-FileHash -Algorithm SHA256 $OutFile).Hash))
			}
			if ($LabelFile) {
				if (-not(Test-Path -Path $LabelFile)) {
					New-Item -Path $LabelFile -Force
				}
				$asmInfo.symbols.ForEach({"al {0:x6} .{1}" -f $_.Value, $_.Name}) | set-content -path $LabelFile -Force
			}
		}

		return ($asmInfo)
	}
}

