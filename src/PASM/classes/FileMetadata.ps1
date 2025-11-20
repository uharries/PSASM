	class FileMetadata {
		[string]$FileName
		[bool]  $IncludeOnce = $false
		[bool]  $HasBeenIncluded = $false

		FileMetadata([string]$fileName) {
			$this.FileName = $fileName
		}
	}
