class Scope {
	[int] $Id
	[string] $Name
	[int] $ParentId
	[int] $StartIndex	# Start index of where in source the scope starts (could be char offset or token index)
	[int] $EndIndex		# End index...
	[int] $StartLine
	[int] $StartColumn
	[int] $EndLine
	[int] $EndColumn

	Scope([int] $id, [string] $name, [int] $parentId, [int] $startIndex, [int] $endIndex, [int] $startLine, [int] $startColumn, [int] $endLine, [int] $endColumn) {
		$this.Id = $id
		$this.Name = $name
		$this.ParentId = $parentId
		$this.StartIndex = $startIndex
		$this.EndIndex = $endIndex
		$this.StartLine = $startLine
		$this.StartColumn = $startColumn
		$this.EndLine = $endLine
		$this.EndColumn = $endColumn
	}

	Scope() {}
}
