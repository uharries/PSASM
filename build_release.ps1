param(
    [string]$ModuleName = 'PSASM',
    [string]$SourcePath = '.\src',
    [string]$OutputPath = '.\build'
)

# Ensure outputPath exists and remove old release artifacts
if (-Not (Test-Path -Path $OutputPath)) { New-Item -Path $OutputPath -ItemType Directory -Force }
$ModuleSource = Join-Path -Path $SourcePath -ChildPath $ModuleName
$Destination = Join-Path -Path $OutputPath -ChildPath $ModuleName
Remove-Item -Path $Destination -Recurse -Force -ErrorAction SilentlyContinue

# Actually copy all the files to the build folder
Copy-Item -Path $ModuleSource -Destination $Destination -Recurse -Force

Write-Host "✅ Build complete. Module available at: $Destination" -ForegroundColor Green
