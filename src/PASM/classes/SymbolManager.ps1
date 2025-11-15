class SymbolManager {
	[hashtable]$Symbols = [ordered]@{}	### $Symbols[$Pass][$Scope][$Name][$Instance].Property
	[int]$CurrentPass
	[Scope[]]$scopes

	[void] SetSymbol([SymbolEntry]$symbol) {
		# Write-Host "SetSymbol(symbol={name=$($symbol.Name), scopeId=$($symbol.ScopeId), pass=$($symbol.Pass), value=$($symbol.Value)})" -ForegroundColor Magenta
		$pass = $symbol.Pass
		# $pass = [string]$symbol.Pass
		$scope = $symbol.ScopeId
		$name = $symbol.Name

		if (-not $this.Symbols[$pass]) {
			# Write-Host "  SetSymbol: Initializing Symbols for Pass $pass" -ForegroundColor Magenta
			$this.Symbols[$pass] = [ordered]@{}
		}

		if (-not $this.Symbols[$pass][$scope]) {
			# Write-Host "  SetSymbol: Initializing Symbols for Scope '$scope' in Pass $pass" -ForegroundColor Magenta
			$this.Symbols[$pass][$scope] = [ordered]@{}
		}

		if (-not $this.Symbols[$pass][$scope][$name]) {
			# Write-Host "  SetSymbol: Initializing Symbols for Name '$name' in Scope '$scope' in Pass $pass" -ForegroundColor Magenta
			$this.Symbols[$pass][$scope][$name] = [System.Collections.Generic.List[SymbolEntry]]::new()
		}

		# Write-Host "  SetSymbol: Adding Symbol '$name' in Scope '$scope' in Pass $pass with Value $($symbol.Value)" -ForegroundColor Magenta
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

	[SymbolEntry] GetSymbol($name, [int]$callerScopeId, [int]$callerLine, [int]$callerColumn, [System.Management.Automation.InvocationInfo]$invocation) {
		$r = $this.ResolveNameAndScope($name, $callerScopeId)
		if (-not $r.Resolved) {
			throw "Unresolved symbol '$name'. Scope could not be resolved in line $($callerLine), column $($callerColumn)"
		}
		$name = $r.Name
		$scopeId = $r.ScopeId

		$scope = [string]$scopeId
		$line = $invocation.ScriptLineNumber
		$column = $invocation.OffsetInLine
		$numPasses = $this.Symbols.Count
		$currPass = $this.CurrentPass
		# $currentPass = $numPasses - 1
		$previousPass = $currPass - 1

		# Write-Host "  GetSymbol: numPasses = $numPasses, currPass = $currPass" -ForegroundColor Magenta

		### In this case previousPass is pass 0, and Pass 0 should add all labels
		# if ($currPass -le 1) {
		# 	if ($this.Symbols[0][$scope] -and $this.Symbols[0][$scope][$name]) {
		# 		write-host "  GetSymbol: Symbol '$name' found in scope '$scope' in pass 0: val: $($this.Symbols[0][$scope][$name][-1].Value)" -ForegroundColor Magenta
		# 		return $this.Symbols[0][$scope][$name][-1]
		# 	}
		# }

		if ($this.CurrentPass -gt 0) {
			# Write-Host "NUMPASSES $numPasses CurrentPass $($this.currentPass) PREV PASS: $previousPass"
			# Write-Host "Symbol Count: $($this.Symbols.Count)"
			# Write-Host "Scope: $scope"
			# foreach ($e in $this.GetSymbolTable() ) {
			# 	Write-Host "SYMBOL: $($e.Scope).$($e.Name) = $($e.Value)"
			# }

			# Write-Host ($this.GetSymbolTable | %{$_ |Out-String})
			if ($this.Symbols[$previousPass]?[$scope]) {
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
				# return [SymbolEntry]::new()
				throw "Unresolved symbol '$name'. Scope '$scope' not found in line $($callerLine), column $($callerColumn)"
			}
		} else {
			throw "GetSymbol() called in pass 0. This should never happen!"
		}
	}


	[boolean] TestSymbol([string]$name, [int]$callerScopeId) {
		if ($this.ResolveNameAndScope($name, $callerScopeId).Resolved) { return $true } else { return $false }
	}

	[object] ResolveNameAndScope([string]$name, [int]$callerScopeId) {
		# Split dotted string, but keep leading dot if present
		$v = $name.Split('.')
		if ($v[0].Length -eq 0) {
			$v[1] = '.' + $v[1]
			$v = $v[1..($v.Count - 1)]
		}

		$names = $v
		$nameIsQualified = $names.Count -gt 1
		$scopeId = $callerScopeId

		if ($nameIsQualified) {
			# --- Qualified lookup ---
			# Start by finding matching top-level scope
			while ($true) {
				$match = $this.scopes.Where({$_.ParentId -eq $this.scopes[$scopeId].ParentId -and $_.Name -eq $names[0]})
				if ($match) { $scopeId = $match.Id; break }
				if ($scopeId -eq $this.scopes[$scopeId].ParentId) { break } # Reached root
				$scopeId = $this.scopes[$scopeId].ParentId
			}
			# Descend through subscopes - if more than two names.. otherwise we have found the scope already
			if ($names.count -gt 2) {
				foreach ($n in $names[1..($names.Count - 2)]) {
					$next = $this.scopes.Where({$_.ParentId -eq $scopeId -and $_.Name -eq $n})
					if ($next.Count -gt 1) { throw "Ambiguous scope name '$n' in qualified symbol name '$name'" }
					if ($next) { $scopeId = $next.Id } else { return [PSCustomObject]@{Resolved = $false;ScopeId = $null;ScopeName = $null;Name = $null} }
				}
			}
			$finalName = $names[-1]
			if ($this.Symbols[0]?[[string]$scopeId]?[$finalName]) {
				return [PSCustomObject]@{Resolved = $true;ScopeId = $scopeId; ScopeName = $this.scopes[$ScopeId].Name;Name = $finalName}
			} else {
				return [PSCustomObject]@{Resolved = $false;ScopeId = $null;ScopeName = $null;Name = $null}
			}
		} else {
			# --- Unqualified lookup ---
			while ($true) {
				if ($this.Symbols[0]?[[string]$scopeId]?[$name]) { return [PSCustomObject]@{Resolved = $true;ScopeId = $scopeId;ScopeName = $this.scopes[$ScopeId].Name;Name = $name} }
				if ($scopeId -eq 0) { break }      # stop after checking global scope
				$scopeId = $this.scopes[$scopeId].ParentId
			}
			return [PSCustomObject]@{Resolved = $false;ScopeId = $null;ScopeName = $null;Name = $null}
		}
	}




	# 	$v=$name.Split('.')
	# 	# Split dotted string, but keep leading dot if present
	# 	if ($v[0].Length -eq 0) {$v[1]='.'+$v[1];$v=$v[1..($v.count-1)]}
	# 	$names = $v
	# 	foreach ($n in $names) {
	# 		$scopeId = $this.scopes.Where({$_.ParentId -eq $scopeId -and $_.Name -eq $n}, 'Last')?.Id ?? $scopeId
	# 	}
	# 	$name = $names[-1]
	# 	$scope = [string]$scopeId
	# 	if ($this.Symbols[0] -and $this.Symbols[0][$scope] -and $this.Symbols[0][$scope][$name]) {
	# 		return $true
	# 	}
	# 	$scope = 'Unscoped'
	# 	if ($this.Symbols[0] -and $this.Symbols[0][$scope] -and $this.Symbols[0][$scope][$name]) {
	# 		return $true
	# 	}
	# 	### ToDo: Implement check for symbol in parent scopes
	# 	else {
	# 		return $false
	# 	}
	# }

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

	[object[]] GetFullSymbolTable() {
		$table = foreach ($pass in $this.Symbols.Keys) {
			foreach ($scope in $this.Symbols[$pass].Keys) {
				foreach ($name in $this.Symbols[$pass][$scope].Keys) {
					for ($instance=0; $instance -lt $this.Symbols[$pass][$scope][$name].Count; $instance++) {
						$symbol = $this.Symbols[$pass][$scope][$name][$instance]
						[PSCustomObject]@{
							Pass      = $pass
							Scope     = $scope
							Name      = $name
							Instance  = $instance
							SymName   = $symbol.Name
							SymScope  = $symbol.ScopeId
							SymPass   = $symbol.Pass
							Value     = $symbol.Value
							Width     = $symbol.Width
							Line      = $symbol.Line
							Column    = $symbol.Column
						}
					}
				}
			}
		}

		return $table | sort Pass, Scope, Name, Instance | ft * -auto
	}

}
