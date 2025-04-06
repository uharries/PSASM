param(
    [string]$ModuleName = 'PASM'
)

$SourcePath = Join-Path -Path (Resolve-Path ./src) -ChildPath $ModuleName
$ModulePath = Join-Path -Path $SourcePath -ChildPath "$ModuleName.psm1"

Import-Module -Name $ModulePath -Force -Verbose
Write-Host "✅ Development module loaded from: $SourcePath" -ForegroundColor Cyan
