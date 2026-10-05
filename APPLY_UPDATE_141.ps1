param(
  [ValidateSet('Prepare','Copy','Check','CommitApp')]
  [string]$Stage = 'Prepare',
  [string]$UpdateRoot = '',
  [string]$AppRepo = (Join-Path $env:USERPROFILE 'Desktop\2027\zameel-feature-control')
)
$ErrorActionPreference = 'Stop'
function Assert-Exit([string]$Message) { if ($LASTEXITCODE -ne 0) { throw $Message } }
function Get-NormalizedHash([string]$Path) {
  $text = [IO.File]::ReadAllText($Path).Replace("`r`n", "`n")
  $sha = [Security.Cryptography.SHA256]::Create()
  try { return ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($text)))).Replace('-', '').ToLowerInvariant() }
  finally { $sha.Dispose() }
}
function Read-Manifest([string]$Root) {
  $manifest = Get-Content -LiteralPath (Join-Path $Root 'UPDATE_141_MANIFEST.json') -Raw -Encoding UTF8 | ConvertFrom-Json
  if ($manifest.release -ne 141 -or $manifest.files.Count -ne 4) { throw 'Invalid update manifest' }
  foreach ($entry in $manifest.files) {
    if ($entry.path -match '(^/|^[A-Za-z]:|(^|[/\\])\.\.([/\\]|$)|(^|[/\\])\.git([/\\]|$))') { throw 'Unsafe manifest path' }
    if ((Get-FileHash -LiteralPath (Join-Path $Root $entry.path) -Algorithm SHA256).Hash -ne $entry.sha256) { throw "Source hash mismatch: $($entry.path)" }
  }
  return $manifest
}
$remote = git -C $AppRepo remote get-url origin
Assert-Exit 'Cannot read Git remote'
if ($remote.TrimEnd('/') -ne 'https://github.com/mohammadaldaleshe-maker/zameel.git') { throw 'Unexpected repository' }
$pubspec = [IO.File]::ReadAllText((Join-Path $AppRepo 'pubspec.yaml'))
if ($pubspec -notmatch '(?m)^version:\s*2\.0\.6\+15\s*$') { throw 'This patch requires update 140 / 2.0.6+15' }
if ($Stage -eq 'Prepare') {
  $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
  $update = Join-Path $env:USERPROFILE "Desktop\Zameel_Update_141_$stamp"
  $backup = Join-Path $env:USERPROFILE "Desktop\Zameel_Backup_Before_141_$stamp"
  $sourceRoot = Join-Path $update 'APP'
  Expand-Archive -LiteralPath (Join-Path $env:USERPROFILE 'Downloads\Zameel_APP_141_FEED_VIDEO_PATCH.zip') -DestinationPath $sourceRoot
  $manifest = Read-Manifest $sourceRoot
  foreach ($entry in $manifest.files) {
    $original = Join-Path $AppRepo $entry.path
    if (Test-Path -LiteralPath $original) {
      $destination = Join-Path $backup $entry.path
      New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
      Copy-Item -LiteralPath $original -Destination $destination -Force
    }
  }
  $oldManifest = Join-Path $AppRepo 'UPDATE_141_MANIFEST.json'
  if (Test-Path -LiteralPath $oldManifest) {
    New-Item -ItemType Directory -Path $backup -Force | Out-Null
    Copy-Item -LiteralPath $oldManifest -Destination (Join-Path $backup 'UPDATE_141_MANIFEST.json') -Force
  }
  Write-Host "APP patch extracted and verified: $($manifest.files.Count) files"
  Write-Host "Changed-file backup completed: $backup"
  [IO.File]::WriteAllText((Join-Path $env:USERPROFILE 'Downloads\Zameel_Update_141_Path.txt'), $update)
  Write-Host "Update root: $update"
  return
}
if (-not $UpdateRoot -or -not (Test-Path -LiteralPath $UpdateRoot)) { throw 'Supply -UpdateRoot from Prepare' }
$sourceRoot = Join-Path $UpdateRoot 'APP'
$manifest = Read-Manifest $sourceRoot
if ($Stage -eq 'Copy') {
  $galleryPath = Join-Path $AppRepo 'lib\widgets\post_media_gallery.dart'
  $hash = Get-NormalizedHash $galleryPath
  if ($hash -ne $manifest.base_gallery_sha256 -and $hash -ne $manifest.new_gallery_sha256) { throw 'Media gallery differs from update 140; stopped without overwriting it' }
  foreach ($entry in $manifest.files) {
    $destination = Join-Path $AppRepo $entry.path
    New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $sourceRoot $entry.path) -Destination $destination -Force
    if ((Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash -ne $entry.sha256) { throw "Copy verification failed: $($entry.path)" }
  }
  Copy-Item -LiteralPath (Join-Path $sourceRoot 'UPDATE_141_MANIFEST.json') -Destination (Join-Path $AppRepo 'UPDATE_141_MANIFEST.json') -Force
  Write-Host "APP patch copied and verified: $($manifest.files.Count) files"
  return
}
if ((Get-NormalizedHash (Join-Path $AppRepo 'lib\widgets\post_media_gallery.dart')) -ne $manifest.new_gallery_sha256) { throw 'Run Copy before Check or CommitApp' }
if ($Stage -eq 'Check') {
  Push-Location -LiteralPath $AppRepo
  try {
    flutter analyze; Assert-Exit 'Flutter analysis failed'
    flutter test --no-pub; Assert-Exit 'Flutter tests failed'
  } finally { Pop-Location }
  Write-Host 'APP checks passed. Build on GitHub only. No SQL or ADMIN update.'
  return
}
$files = @($manifest.files | ForEach-Object { $_.path }) + @('UPDATE_141_MANIFEST.json')
$staged = @(git -C $AppRepo diff --cached --name-only)
Assert-Exit 'Cannot inspect staged changes'
$unexpected = @($staged | Where-Object { $_ -notin $files })
if ($unexpected.Count -gt 0) { $unexpected; throw 'Staged files outside update 141; review first' }
$branch = git -C $AppRepo branch --show-current
Assert-Exit 'Cannot read branch'
if ($branch -ne 'main') { throw 'Expected main branch' }
git -C $AppRepo fetch origin main; Assert-Exit 'Git fetch failed'
git -C $AppRepo merge-base --is-ancestor origin/main HEAD; Assert-Exit 'Main is behind or diverged; review first'
git -C $AppRepo add -- $files; Assert-Exit 'Git add failed'
git -C $AppRepo diff --cached --check; Assert-Exit 'Staged diff check failed'
git -C $AppRepo diff --cached --stat
git -C $AppRepo diff --cached --quiet
if ($LASTEXITCODE -eq 1) {
  git -C $AppRepo commit -m 'Render visible feed videos inline instead of static black placeholders'
  Assert-Exit 'Git commit failed'
} elseif ($LASTEXITCODE -ne 0) { throw 'Cannot inspect staged diff' }
git -C $AppRepo push origin main; Assert-Exit 'Git push failed'
git -C $AppRepo status --short --branch
