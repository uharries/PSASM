class TokenStream {
	[Tokenizer]$Tokenizer
	[System.Collections.Generic.List[object]]$Buffer = @()
	[int]$Index = 0

	TokenStream([Tokenizer]$tokenizer) {
		$this.Tokenizer = $tokenizer
	}

	[object] Next() {
		if ($this.Index -lt $this.Buffer.Count) {
			return $this.Buffer[$this.Index++]
		}
		$token = $this.Tokenizer.NextToken()
		if ($token -ne $null) {
			$this.Buffer.Add($token)
			$this.Index++
		}
		return $token
	}

	[object] Peek([int]$ahead) {
		$target = $this.Index + $ahead
		while ($target -ge $this.Buffer.Count) {
			$token = $this.Tokenizer.NextToken()
			if ($token -eq $null) { break }
			$this.Buffer.Add($token)
		}
		return $this.Buffer?[$target]
	}

	[object] Peek() {
		return $this.Buffer?[$this.Index]
	}

	[object] Previous() {
		if ($this.Index -gt 0) {
			return $this.Buffer[$this.Index - 1]
		}
		return $null
	}
}
