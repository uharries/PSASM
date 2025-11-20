class InputFileStack {
	[System.Collections.Generic.Stack[InputFileContext]]$Stack = [System.Collections.Generic.Stack[InputFileContext]]::new()
	[System.Collections.Generic.HashSet[string]]$IncludeOnceFiles = [System.Collections.Generic.HashSet[string]]::new()

	[void] PushFile([string]$path) {
		$resolved = if ($this.Stack.Count -eq 0) {
			# First file: resolve to absolute path directly
			(Resolve-Path $path).Path
		} else {
			# Nested include: resolve relative to current context
			$this.ResolveInclude($path)
		}

		if ($this.IncludeOnceFiles.Contains($resolved)) {
			return  # silently skip re-inclusion
		}

		$ctx = [InputFileContext]::new($resolved)
		$this.Stack.Push($ctx)
	}


	[void] PushVirtualFile([string]$filename, [string]$content) {
		$this.Stack.Push([InputFileContext]::new($filename, $content))
	}

	[void] PopFile() {
		if ($this.Stack.Count -gt 0) {
			$ctx = $this.Stack.Pop()
			$ctx.Close()
		}
	}

	[char] ReadChar() {
		while ($this.Stack.Count -gt 0) {
			$ctx = $this.Stack.Peek()
			$char = $ctx.ReadChar()
			if ($char -ne 0) { return $char }
			else { $this.PopFile() }
		}
		return 0
	}

	[object] CurrentContext() {
		if ($this.Stack.Count -eq 0) { return $null }
		$ctx = $this.Stack.Peek()
		return @{ File=$ctx.FilePath; Line=$ctx.Line; Column=$ctx.Column }
	}

	[void] AddIncludeDir([string]$path) {
		if ($this.Stack.Count -eq 0) { throw "No active file context" }
		$this.Stack.Peek().AddIncludeDir($path)
	}

	[string] ResolveInclude([string]$filename) {
		if ([System.IO.Path]::IsPathRooted($filename)) { return $filename }

		if ($this.Stack.Count -eq 0) { throw "No active file context" }
		$ctx = $this.Stack.Peek()

		foreach ($dir in $ctx.IncludeDirs) {
			$candidate = [System.IO.Path]::Combine($dir, $filename)
			if (Test-Path $candidate) { return $candidate }
		}

		throw "Include file not found: $filename"
	}

	[void] MarkCurrentFileIncludeOnce() {
		if ($this.Stack.Count -eq 0) { return }
		$ctx = $this.Stack.Peek()
		[void]$this.IncludeOnceFiles.Add($ctx.FilePath)
	}

}
