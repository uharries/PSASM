class SymbolManager {
	[hashtable]$Symbols = [ordered]@{}	### $Symbols[$Pass][$Scope][$Name][$Instance].Property
	[int]$CurrentPass
	[Scope[]]$scopes

	[void] SetSymbol([SymbolEntry]$symbol) {
		$pass = $symbol.Pass
		# $pass = [string]$symbol.Pass
		$scope = $symbol.ScopeId
		$name = $symbol.Name

		if (-not $this.Symbols[$pass]) {
			$this.Symbols[$pass] = [ordered]@{}
		}

		if (-not $this.Symbols[$pass][$scope]) {
			$this.Symbols[$pass][$scope] = [ordered]@{}
		}

		if (-not $this.Symbols[$pass][$scope][$name]) {
			$this.Symbols[$pass][$scope][$name] = [System.Collections.Generic.List[SymbolEntry]]::new()
		}

		$this.Symbols[$pass][$scope][$name].Add($symbol)
	}

	[void] AddUnscopedSymbol([string]$name) {
		$sym = [SymbolEntry]::new()
		$sym.Name = $name
		$sym.ScopeId = 'Unscoped'
		$this.SetSymbol($sym)
	}

	[void] AddUnresolvedSymbol([string]$name, [string]$scopeId, [int]$line, [int]$column) {
		$sym = [SymbolEntry]::new()
		$sym.Name = $name
		$sym.ScopeId = $scopeId
		$sym.Line = $line
		$sym.Column = $column
		$this.SetSymbol($sym)
	}


	[SymbolEntry] GetSymbol($name, [int]$scopeId, [int]$callerLine, [int]$callerColumn, [System.Management.Automation.InvocationInfo]$invocation) {
		$names = $name.Split('.')
		$nameIsQualified = $names.count -gt 1 ? $true : $false

		if ($nameIsQualified) {
			### Find start scope
			while ($true) {
				$match = $this.scopes.Where({$_.ParentId -eq $this.scopes[$scopeId].ParentId -and $_.Name -eq $names[0]})
				if ($match) { $scopeId = $match.Id; break }
				if ($scopeId -eq $this.scopes[$scopeId].ParentId) { break }
				$scopeId = $this.scopes[$scopeId].ParentId
			}
			### Find scope of symbol
			foreach ($n in $names) {
				$scopeId = $this.scopes.Where({$_.ParentId -eq $scopeId -and $_.Name -eq $n})?.Id ?? $scopeId
			}
			$name = $names[-1]
		} else {
			### Find scope of symbol
			while ($scopeId -ne 0 -and -not $this.Symbols[0][[string]$scopeId]?[$name]) {
				$scopeId = $this.scopes[$scopeId].ParentId
			}
		}

		$scope = [string]$scopeId
		$line = $invocation.ScriptLineNumber
		$column = $invocation.OffsetInLine
		$numPasses = $this.Symbols.Count
		$currPass = $this.CurrentPass
		# $currentPass = $numPasses - 1
		$previousPass = $currPass - 1

		### In this case previousPass is pass 0, and Pass 0 should add all labels
		if ($currPass -le 1) {
			if ($this.Symbols[0][$scope] -and $this.Symbols[0][$scope][$name]) {
				return $this.Symbols[0][$scope][$name][-1]
			}
		}

		if ($previousPass -ge 0) {
			# Write-Host "NUMPASSES $numPasses CurrentPass $currentPass PREV PASS: $previousPass"
			# Write-Host $this.Symbols.Count
			# Write-Host $this.Symbols[$previousPass-1]
			# Write-Host $this.Symbols[$previousPass]
			# Write-Host $this.Symbols
			if ($this.Symbols[$previousPass][$scope]) {
				if ($this.Symbols[$previousPass][$scope][$name]) {
					$numPreviousInstances = $this.Symbols[$previousPass][$scope][$name].Count
					if ($this.Symbols[$currPass]) {
						if ($this.Symbols[$currPass][$scope]) {
							if ($this.Symbols[$currPass][$scope][$name]) {
								$numCurrentInstances = $this.Symbols[$currPass][$scope][$name].Count
								$currentInstance = $numCurrentInstances - 1
								if ($numCurrentInstances -lt $numPreviousInstances) {
									if ($callerLine -lt $this.Symbols[$currPass][$scope][$name][$currentInstance].Line -or ($callerLine -eq $this.Symbols[$currPass][$scope][$name][$currentInstance].Line -and $callerColumn -lt $this.Symbols[$currPass][$scope][$name][$currentInstance].Column)) {
										### For forward references
										return $this.Symbols[$previousPass][$scope][$name][$currentInstance+1]
									}
										### For backward references
										return $this.Symbols[$currPass][$scope][$name][$currentInstance]
								} else {
									return $this.Symbols[$currPass][$scope][$name][$currentInstance]
								}
							} else {
								return $this.Symbols[$previousPass][$scope][$name][0]
							}
						} else {
							return $this.Symbols[$previousPass][$scope][$name][0]
						}
					} else {
						return $this.Symbols[$previousPass][$scope][$name][0]
					}
				} else {
					throw "Unresolved symbol in scope '$scope'. Symbol '$name' not found in line $($callerLine), column $($callerColumn)"
				}
			} else {
				throw "Unresolved symbol '$name'. Scope '$scope' not found in line $($callerLine), column $($callerColumn)"
			}
		} else {
			return [SymbolEntry]::new()
		}
	}


    [boolean] TestSymbol([string]$name, [int]$scopeId) {
		$names=$name.Split('.')
		foreach ($n in $names) {
			$scopeId = $this.scopes.Where({$_.ParentId -eq $scopeId -and $_.Name -eq $n}, 'Last')?.Id ?? $scopeId
		}
		$name = $names[-1]
		$scope = [string]$scopeId
        if ($this.Symbols[0] -and $this.Symbols[0][$scope] -and $this.Symbols[0][$scope][$name]) {
            return $true
        }
		$scope = 'Unscoped'
        if ($this.Symbols[0] -and $this.Symbols[0][$scope] -and $this.Symbols[0][$scope][$name]) {
            return $true
        }
		### ToDo: Implement check for symbol in parent scopes
        else {
            return $false
        }
    }

	[object[]] GetSymbolTable() {
		$table = foreach ($scopeId in $this.Symbols[$this.CurrentPass].Keys) {
			foreach ($name in $this.Symbols[$this.CurrentPass][$scopeId].Keys) {
				$sym = $this.Symbols[$this.CurrentPass][$scopeId][$name][-1]
				[pscustomobject]@{
					Scope    = $scopeId
					Name     = $name
					Value    = $sym.value
				}
			}
		}
		return $table
	}

}
