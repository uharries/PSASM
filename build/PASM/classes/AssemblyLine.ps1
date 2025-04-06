class AssemblyLine {
	[UInt16]$addr
	[byte[]]$bytes
	[int]$lineNumber
	[int]$charPosition
	[string]$asmLineText
	[string]$psLineText
	[string]$fileName

	AssemblyLine([UInt16]$addr, [byte[]]$bytes, [int]$lineNumber, [int]$charPosition, [string]$asmLineText, [string]$psLineText, [string]$fileName) {
		$this.addr = $addr;
		$this.bytes = $bytes;
		$this.lineNumber = $lineNumber;
		$this.charPosition = $charPosition;
		$this.asmLineText = $asmLineText;
		$this.psLineText = $psLineText;
		$this.fileName = $fileName;
	}
}
