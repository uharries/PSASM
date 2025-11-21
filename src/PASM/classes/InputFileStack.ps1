class InputFileStack {
	[System.Collections.Generic.Stack[Object]]$Stack = [System.Collections.Generic.Stack[InputFileContext]]::new()
	[System.Collections.Generic.HashSet[string]]$IncludeOnceFiles = [System.Collections.Generic.HashSet[string]]::new()

	[bool] IsRootedPath([string]$path) {
		# Doing this with native PS and/or .net methods is surprisingly hard.
		# So we use a regex to cover common absolute path formats on Windows and Unix.
		# Path may still contain relative components like .. or . after this check.
		# Regex explanation:
		# ^ / $							- anchors whole string.
		# /.*							- Unix absolute paths.
		# [A-Za-z]:[\\/].*				- Windows drive letter C:\... or D:/....
		# \\\\\?\\.* and \\\\\.\\.*		- \\?\... and \\.\... extended/device forms.
		# \\\\[^\\\/]+[\\/][^\\\/]+.*	- UNC root \\server\share\....
		# [^\\\/:\s]+:[\\/]?.*			- PowerShell/PSDrive and provider-style drive names: one-or-more chars that are not backslash/slash/colon/space, then :, optionally a \ or /, then anything. This covers Env:, Env:\Path, HKLM:\Software, MyDrive:\folder.
		return $path -match '^(?:/.*|[A-Za-z]:[\\/].*|\\\\\?\\.*|\\\\\.\\.*|\\\\[^\\\/]+[\\/][^\\\/]+.*|[^\\\/:\s]+:[\\/]?.*)$'
	}

	[void] PushFile([string]$path) {
		# Resolve the path to a full path
		$resolved = $this.ResolvePath($path)

		# Detect circular include using for loop
		$stackArray = $this.Stack.ToArray()	# Enumeration issues if we use foreach directly on the stack
		for ($i = 0; $i -lt $stackArray.Count; $i++) {
			if ($stackArray[$i].FilePath -eq $resolved) {
				$origin = ($i -gt 0) ? $stackArray[$i - 1].FilePath : $stackArray[0].FilePath
				$chain  = ($stackArray | ForEach-Object FilePath) -join " -> "
				throw "Circular include detected: '$resolved' was already included by '$origin'. Chain: $chain"
			}
		}

		# Check for include-once
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

	[string] ResolvePath([string]$path) {
		if ($this.IsRootedPath($path) -or $this.Stack.Count -eq 0) {
			# To support PSDrive and provider paths, we use ProviderPath here
			return (Resolve-Path $path).ProviderPath
		}

		if ($path -notmatch '^(?:\.\.[\\/]|\.?[\\/]).*') {
			# We only search IncludeDirs for non-relative includes.
			$ctx = $this.Stack.Peek()
			foreach ($dir in $ctx.IncludeDirs) {
				if ($resolved = Join-Path -Path $dir -ChildPath $path -Resolve -ErrorAction SilentlyContinue) {
					return $resolved
				}
			}
		}

		return (Resolve-Path $path).Path

		# throw "Include file not found: $path"
	}

	[void] MarkCurrentFileIncludeOnce() {
		if ($this.Stack.Count -eq 0) { return }
		$ctx = $this.Stack.Peek()
		[void]$this.IncludeOnceFiles.Add($ctx.FilePath)
	}

}
