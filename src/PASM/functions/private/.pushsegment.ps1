function .pushsegment {
    [PASM()] param (
        [Parameter(Mandatory)]
        [string]$name,
        [int]$Start = -1,
        [string]$StartAfter = $null,
        [int]$End = -1,
        [int]$Size = -1,
        [int]$Run = -1,
        [int]$Align = 0,
        [switch]$Fill = $false,
        [byte[]]$FillBytes = @(,0),
        [switch]$AllowOverlap = $false,
        [switch]$Virtual = $false
    )
    $pasm.Segments.Push()
    .segment @PSBoundParameters
}
