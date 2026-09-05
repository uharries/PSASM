class ScopeManager {
	[int]$nextScopeId = 0
	[System.Collections.Generic.Stack[int]]$scopeStack
	[System.Collections.Generic.List[object]]$scopes


	ScopeManager() {
		$this.scopeStack = [System.Collections.Generic.Stack[int]]::new()
		$this.scopes = [System.Collections.Generic.List[Scope]]::new()
		$this.EnterNewScope(0,1,1)
	}


	[void] EnterNewScope([string]$name, [int]$startIndex, [int]$line, [int]$column) {
		$scope = [Scope]::new()
		$scope.id = $this.nextScopeId++
		$scope.Name = $name
		$scope.parentId = if ($this.scopeStack.Count -gt 0) { $this.scopeStack.Peek() } else { 0 }
		$scope.startIndex = $startIndex
		$scope.StartLine = $line
		$scope.StartColumn = $column
		$this.scopes.Add($scope)
		$this.scopeStack.Push($scope.Id)
	}


	[void] EnterNewScope([int]$startIndex, [int]$line, [int]$column) {
		$this.EnterNewScope("", $startIndex, $line, $column)
	}


	[void] ExitNewScope([int]$endIndex, [int]$line, [int]$column) {
		$id = $this.scopeStack.Pop()
		$scope = $this.scopes | Where-Object { $_.id -eq $id }
		$scope.endIndex = $endIndex
		$scope.EndLine = $line
		$scope.EndColumn = $column
		if ($this.scopeStack.Count -eq 0) {
			$this.EnterScope(0)
		}
	}


	[void] EnterScope([int]$startIndex) {
		$scope = $this.scopes | Where-Object { $_.startIndex -eq $startIndex }
		$this.scopeStack.Push($scope.Id)
	}


	[void] ExitScope() {
		$null = $this.scopeStack.Pop()
	}


	[int] GetCurrentScope() {
		return $this.scopeStack.Peek()
	}


	[Scope] GetScopeById([int] $id) {
		return $this.Scopes | Where-Object { $_.Id -eq $id }
	}


	[Scope] GetScopeByIndex([int] $index) {
		return $this.Scopes | Where-Object { $_.StartIndex -le $index -and $_.EndIndex -ge $index } | Sort-Object StartIndex -Descending | Select-Object -First 1
	}


	[bool] IsVisible([int] $definitionScopeId, [int] $currentScopeId) {
		if ($definitionScopeId -eq $currentScopeId) {
			return $true
		}

		$current = $this.GetScopeById($currentScopeId)
		while ($current -and $current.ParentId -ne 0) {
			if ($current.ParentId -eq $definitionScopeId) {
				return $true
			}
			$current = $this.GetScopeById($current.ParentId)
		}

		return $false
	}

	[string] GetFullyQualifiedName([Scope]$scope) {
		$parts = [System.Collections.Generic.List[string]]::new()

		while ($scope -and $scope.Id -ne 0) {
			if ($scope.Name) {
				$parts.Add($scope.Name)
			}

			$scope = $this.scopes[$scope.ParentId]
		}

		$parts.Reverse()

		return $parts -join '.'
	}


	[object[]] GetScopeTable() {
		$table = foreach ($scope in $this.scopes) {
			$obj = [pscustomobject]@{
				FQName      = $this.GetFullyQualifiedName($scope)
				Id          = $scope.Id
				Name        = $scope.Name
				ParentId    = $scope.ParentId
				StartIndex  = $scope.StartIndex
				EndIndex    = $scope.EndIndex
				StartLine   = $scope.StartLine
				StartColumn = $scope.StartColumn
				EndLine     = $scope.EndLine
				EndColumn   = $scope.EndColumn
			}
			$obj.PSObject.TypeNames.Insert(0, 'PSASM.Scope')
			$obj
		}
		return $table
	}
}
