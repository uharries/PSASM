class InputFileContext {
    [string]$FilePath
    [string]$Content
    [int]   $Index    = 0
    [int]   $Length   = 0

    [int]   $Line     = 1
    [int]   $Column   = 1

    [System.Collections.Generic.List[string]]$IncludeDirs = [System.Collections.Generic.List[string]]::new()
    [bool]$IncludeOnce = $false

    InputFileContext([string]$resolvedPath) {
        $this.FilePath = $resolvedPath
        $this.Content  = (Get-Content -Path $resolvedPath -Raw)
		# 					-replace "`r`n", "`n" `
		# 					-replace "`r", "`n" `
		# 					-replace ([char]0x2028), "`n" `
		# 					-replace ([char]0x2029), "`n" `
		# 					-split("`n")
        $this.Length   = $this.Content.Length
        $this.IncludeDirs.Add((Split-Path $resolvedPath -Parent))
    }

    InputFileContext([string]$filename, [string]$content) {
        $this.FilePath = $filename
        $this.Content  = $content
        $this.Length   = $content.Length
        $this.IncludeDirs.Add((Get-Location).Path)
    }

    hidden [bool] IsEOF() {
        return $this.Index -ge $this.Length
    }

    [char] PeekChar() {
        if ($this.IsEOF()) { return 0 }
        return $this.Content[$this.Index]
    }

    [char] ReadChar() {
        if ($this.IsEOF()) { return 0 }

        $ch = $this.Content[$this.Index]
        $this.Index++

        $code = [int][char]$ch

        # newline family
        if ($code -in 10,8232,8233) {
            $this.Line++
            $this.Column = 1
            return "`n"
        }

        # normal char, incl CR
        $this.Column++
        return $ch
    }

	[void] UnReadChar() {
		if ($this.Index -le 0) { return }

		# Step back one char
		$this.Index--

		$ch = $this.Content[$this.Index]
		$code = [int][char]$ch

		if ($this.Column -eq 1) {
			if ($this.Line -gt 1) {
				$this.Line--
				# ---- Recompute column ----
				$i = $this.Index - 1
				$col = 1
				while ($i -ge 0) {
					$c2 = [int][char]$this.Content[$i]
					if ($c2 -in 10,8232,8233) { break }
					$col++
					$i--
				}
				$this.Column = $col
				return
			}
		}
		$this.Column--
	}

    [void] AddIncludeDir([string]$path) {
        $full = (Resolve-Path $path).Path
        $this.IncludeDirs.Add($full)
    }

    [void] Close() {
        # nothing to close, file already loaded
    }
}
