param(
    [Parameter(Mandatory)]
    [string]$Version,        # e.g. "1.4.0" or "1.4.0-beta.1"

    [string]$Message = ''
)

if ($Message -eq '') { $Message = "Release $Version" }

$tag = "v$Version"

# Safety check — make sure working tree is clean
$status = git status --porcelain
if ($status) {
    Write-Host "❌ Working tree is not clean. Commit or stash changes first:" -ForegroundColor Red
    git status --short
    return
}

# Confirm before tagging
Write-Host "About to tag: $tag  ($Message)" -ForegroundColor Cyan
$confirm = Read-Host "Continue? (y/n)"
if ($confirm -ne 'y') { Write-Host "Aborted."; return }

git tag -a $tag -m $Message
git push origin $tag

Write-Host "✅ Tagged and pushed $tag — GitHub Actions will handle the rest." -ForegroundColor Green
Write-Host "   Watch progress at: https://github.com/uharries/pasm/actions" -ForegroundColor Gray
