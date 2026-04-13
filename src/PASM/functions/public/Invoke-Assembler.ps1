
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

	.INPUTS
	An array of strings to process as the assembler source code.

	.OUTPUTS
	An AssemblyResult object containing the properties: Success, ErrorMessage, LoadAddress, Scopes, Symbols, SymbolsFull, PSSource, Segments, SegmentInfo, Assembly, AssemblyList, Binary, BinaryList, BinaryHash, and Tokens.

	.EXAMPLE
	PS> $rc = Invoke-Assembler -SourceFile demo.s -OutFile demo.prg
	Pass 1... OK!
	Pass 2... OK!

	✅ Assembly succeeded.

	Writing 'demo.prg'...File Hash: 7554E67721301AD0A4CDDA94ACA9FEC8A64A9F25A2431CF83616AE9DC619469C

	.EXAMPLE
	PS> '.org $1000; inc $d020; jmp *-3' | Invoke-Assembler -OutFile demo.prg
	Pass 1... OK!
	Pass 2... OK!

	✅ Assembly succeeded.

	Writing 'demo.prg'...File Hash: 7554E67721301AD0A4CDDA94ACA9FEC8A64A9F25A2431CF83616AE9DC619469C

    [OK]  Load=$1000  Size=$0006
#>
function Invoke-Assembler {
	[CmdletBinding()]
	param (
		[Parameter(Position=0)]
		[Alias("I","Input")]
		[string]$SourceFile,

		[Parameter(Position=1)]
		[Alias("O","Output")]
		[string]$OutFile,

		[Parameter()]
		[Alias("lbl")]
		[string]$LabelFile = $SourceFile ? "$($SourceFile -replace '(.*)([.].*)','$1').lbl" : $null,

		[Alias("ps","psfile")]
		[string]$DumpPSfile,

		[Parameter()]
		[Alias("lst")]
		[string]$ListFile = $SourceFile ? "$($SourceFile -replace '(.*)([.].*)','$1').lst" : $null,

		[Parameter(ValueFromPipeline)]
		[object]$InputObject,

		[Alias("l","list")]
		[switch]$ListAssembly,

		[Alias("h","hexdump","DumpHex","dump","hex")]
		[switch]$ListBinary,

		[switch]$NoBanner,

		[Alias("q")]
		[switch]$NoHostOutput,

		[switch]$Version
	)

	BEGIN {
		$ErrorActionPreference = 'Stop'
		function Print-Banner {
			$vTag = format-string -Text "Version $($script:ModuleFullVersion)" -Format Center -OutputStringWidth 21
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
				$null = $SourceLines.AppendLine($InputObject)
			} else {
				Write-Warning -Message "Ignoring unsupported input object: $($InputObject.GetType().FullName)"
			}
		}
	}

	END {
		if (-not $NoHostOutput -and -not $NoBanner) {
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

		try {
			$pasm.Parse()
			$pasm.Assemble()
			$asmInfo = $pasm.ToResult()
			$asmInfo.Success = $true
		} catch {
			$asmInfo = $pasm.ToResult()
			$asmInfo.Success = $false
			$asmInfo.ErrorMessage = $_.Exception.Message
			$_.Exception.Data["AssemblyResult"] = $asmInfo
		}

		if (-not $asmInfo.Success) {
			if (-not $NoHostOutput) {
				Write-Host "`n❌ Assembly failed: $($asmInfo.ErrorMessage)" -ForegroundColor Red
				Write-Host "`nℹ️  `e[3mYou can inspect `e[0m`e[33m`$Error[0].Exception.Data['AssemblyResult']`e[0m `e[3mfor the details, if you did not save the assembly result to a variable.`e[0m`n"
			}
			return $asmInfo
		} else {
			if (-not $NoHostOutput) {
				Write-Host "`n✅ Assembly succeeded.`n" -ForegroundColor Green
			}
		}

		if ($DumpPSfile) {
			$asminfo.psSource | set-content -path $DumpPSfile -Force
		}

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
				$null =New-Item -Path $OutFile -Force
			}
			$asmInfo.Binary | set-content -asbytestream -path $OutFile -Force
			if (-not $NoHostOutput) {
				for ($i = 0; $i -lt 30; $i++) {
					try {
						$hash = (Get-FileHash -Algorithm SHA256 -Path $OutFile -ErrorAction Stop).Hash
						break
					} catch {
						Start-Sleep -Milliseconds 100
					}
				}

				if (-not $hash) {
					Write-Error "Failed to compute file hash for: $OutFile" -ErrorAction Continue
					$hash = "N/A"
				}

				Write-Host ("File Hash: {0:x}" -f $hash)
			}
			if ($LabelFile) {
				if (-not(Test-Path -Path $LabelFile)) {
					$null = New-Item -Path $LabelFile -Force
				}
				$asmInfo.symbols.ForEach({"al {0:x6} .{1}" -f $_.Value, $_.Name}) | set-content -path $LabelFile -Force
			}
		}

		return ($asmInfo)
	}
}

