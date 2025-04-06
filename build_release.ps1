param(
    [string]$ModuleName = 'PASM',
    [string]$SourcePath = '.\src',
    [string]$OutputPath = '.\build',
    [switch]$Zip
)

# Ensure output folder exists
if (-Not (Test-Path -Path $OutputPath)) {
    New-Item -Path $OutputPath -ItemType Directory -Force
}

# Get the latest Git commit hash or use date if Git is not available
try {
    $Version = git describe --tags --abbrev=0
} catch {
    # If Git is not available, fall back to the current date for versioning
    $Version = (Get-Date).ToString('yyyyMMdd.HHmm')
}

Write-Host "Version: $Version" -ForegroundColor Cyan

# Copy module source into output
$ModuleSource = Join-Path -Path $SourcePath -ChildPath $ModuleName
$Destination = Join-Path -Path $OutputPath -ChildPath $ModuleName

Copy-Item -Path $ModuleSource -Destination $Destination -Recurse -Force

# Clean up dev-specific files (tests, logs, etc.)
# $DevFiles = @(
#     "$Destination\test\*",
#     "$Destination\dev_import.ps1",
#     "$Destination\build.ps1",
#     "$Destination\.vscode"
# )

# Remove dev files
# foreach ($File in $DevFiles) {
#     if (Test-Path -Path $File) {
#         Remove-Item -Path $File -Recurse -Force
#     }
# }

# Update the version in the .psd1 file
$Psd1Path = Join-Path -Path $Destination -ChildPath "$ModuleName.psd1"
$Psd1Content = Get-Content -Path $Psd1Path -Raw

# Replace the version string in the .psd1 file
$Psd1Content = $Psd1Content -replace '(\$ModuleVersion\s*=\s*).+', "`$ModuleVersion = '$Version'"

# Write the updated content back to the .psd1 file
$Psd1Content | Set-Content -Path $Psd1Path -Force

# Optionally create a zip file
if ($Zip) {
    $ZipFile = Join-Path -Path $OutputPath -ChildPath "$ModuleName.zip"
    Write-Host "Zipping the module..." -ForegroundColor Yellow
    Compress-Archive -Path $Destination -DestinationPath $ZipFile -Force
    Write-Host "✅ Module zipped at: $ZipFile" -ForegroundColor Green
}

Write-Host "✅ Build complete. Module available at: $Destination" -ForegroundColor Green
