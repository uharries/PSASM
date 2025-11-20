class SourceFile {
	[string]$Filename
	[string]$Content

	SourceFile([string]$filename, [string]$content) {
		$this.Filename = $filename
		$this.Content = $content
	}

}