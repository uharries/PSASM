class InputFileContext {
	[string]$FilePath
	[System.IO.TextReader]$Reader
	[int]$Line = 1
	[int]$Column = 1
	[System.Collections.Generic.List[string]]$IncludeDirs = [System.Collections.Generic.List[string]]::new()
	[bool]$IncludeOnce = $false

	InputFileContext([string]$resolvedPath) {
		$this.FilePath = $resolvedPath
		$this.Reader   = [System.IO.StreamReader]::new($resolvedPath)

		# Default include dir is the file’s own directory
		$this.IncludeDirs.Add([System.IO.Path]::GetDirectoryName($resolvedPath))
	}

	InputFileContext([string]$filename, [string]$content) {
		$this.FilePath = $filename
		$this.Reader   = [System.IO.StringReader]::new($content)

		# Virtual files can default to current working dir
		$this.IncludeDirs.Add((Get-Location).Path)
	}

	[char] ReadChar() {
		$code = $this.Reader.Read()
		if ($code -eq -1) { return 0 }
		if ([char]$code -eq "`n") { $this.Line++; $this.Column = 1 }
		else { $this.Column++ }
		return [char]$code
	}

	[void] Close() { $this.Reader.Close() }

	[void] AddIncludeDir([string]$path) {
		$full = (Resolve-Path $path).Path
		$this.IncludeDirs.Add($full)
	}
}
