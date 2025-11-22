param(
    [string]$ModuleName = 'PASM',
    [string]$SourcePath = '.\src',
    [string]$OutputPath = '.\build',
    [switch]$Zip
)

# Ensure outputPath exists and remove old release artifacts
if (-Not (Test-Path -Path $OutputPath)) { New-Item -Path $OutputPath -ItemType Directory -Force }
$ModuleSource = Join-Path -Path $SourcePath -ChildPath $ModuleName
$Destination = Join-Path -Path $OutputPath -ChildPath $ModuleName
Remove-Item -Path $Destination -Recurse -Force


$manifestPath = Join-Path -Path $ModuleSource -ChildPath "$ModuleName.psd1"
$versionInfo  = Join-Path -Path $ModuleSource -ChildPath "globals" -AdditionalChildPath "VersionInfo.ps1"

$manifest = Test-ModuleManifest $manifestPath
$currentVersion = $manifest.Version

$newVersion = [version]::new($currentVersion.Major, $currentVersion.Minor, $currentVersion.Build + 1)

$buildDate = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss UTCz')
Write-Host "Building Release Version: $newVersion, Build Date: $buildDate" -ForegroundColor Cyan

# Update manifest
$psd1 = Get-Content $manifestPath -Raw
$psd1 = $psd1 -replace "ModuleVersion\s*=\s*'[^']+'", "ModuleVersion = '$newVersion'"
Set-Content $manifestPath $psd1 -Encoding UTF8 -Force

# Generate version info file
@"
# Auto-generated – DO NOT EDIT
`$script:ModuleVersion   = [version]'$newVersion'
`$script:ModuleBuildDate = '$buildDate'
"@ | Set-Content $versionInfo -Encoding UTF8 -Force

# Actually copy all the files to the build folder
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


# Optionally create a zip file
if ($Zip) {
    $ZipFile = Join-Path -Path $OutputPath -ChildPath "$ModuleName.zip"
    Write-Host "Zipping the module..." -ForegroundColor Yellow
    Compress-Archive -Path $Destination -DestinationPath $ZipFile -Force
    Write-Host "✅ Module zipped at: $ZipFile" -ForegroundColor Green
}

Write-Host "✅ Build complete. Module available at: $Destination" -ForegroundColor Green
