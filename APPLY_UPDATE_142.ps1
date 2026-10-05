param(
  [ValidateSet('Prepare','Copy','Check','Sql1','Sql2','DeployFunction','CommitApp')]
  [string]$Stage = 'Prepare',
  [string]$UpdateRoot = '',
  [string]$AppRepo = (Join-Path $env:USERPROFILE 'Desktop\2027\zameel-feature-control')
)
$ErrorActionPreference = 'Stop'
function Assert-Exit([string]$Message) { if ($LASTEXITCODE -ne 0) { throw $Message } }
function Get-TextHash([string]$Path) {
  $text = [IO.File]::ReadAllText($Path).Replace("`r`n", "`n")
  $sha = [Security.Cryptography.SHA256]::Create()
  try { return [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($text))).Replace('-', '').ToLowerInvariant() }
  finally { $sha.Dispose() }
}
function Read-Manifest([string]$Root) {
  $m = Get-Content -LiteralPath (Join-Path $Root 'UPDATE_142_MANIFEST.json') -Raw -Encoding UTF8 | ConvertFrom-Json
  if ($m.release -ne 142 -or $m.files.Count -lt 10) { throw 'Invalid update manifest' }
  foreach ($entry in $m.files) {
    if ($entry.path -match '(^/|^[A-Za-z]:|(^|[/\\])\.\.([/\\]|$)|(^|[/\\])\.git([/\\]|$))') { throw 'Unsafe manifest path' }
    if ((Get-FileHash -LiteralPath (Join-Path $Root $entry.path) -Algorithm SHA256).Hash -ne $entry.sha256) { throw "Source mismatch: $($entry.path)" }
  }
  return $m
}
$remote = git -C $AppRepo remote get-url origin
Assert-Exit 'Cannot read repository'
if ($remote.TrimEnd('/') -ne 'https://github.com/mohammadaldaleshe-maker/zameel.git') { throw 'Unexpected repository' }
$pubspec = [IO.File]::ReadAllText((Join-Path $AppRepo 'pubspec.yaml'))
if ($pubspec -notmatch '(?m)^version:\s*2\.0\.(6\+15|7\+16)\s*$') { throw 'Requires release 140/141 or installed patch 142' }
if ($Stage -eq 'Prepare') {
  $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
  $update = Join-Path $env:USERPROFILE "Desktop\Zameel_Update_142_$stamp"
  $backup = Join-Path $env:USERPROFILE "Desktop\Zameel_Backup_Before_142_$stamp"
  $root = Join-Path $update 'APP'
  Expand-Archive -LiteralPath (Join-Path $env:USERPROFILE 'Downloads\Zameel_APP_142_INCOMING_CALLS_PATCH.zip') -DestinationPath $root
  $manifest = Read-Manifest $root
  New-Item -ItemType Directory -Path $backup -Force | Out-Null
  $existing = @()
  foreach ($entry in $manifest.files) {
    $old = Join-Path $AppRepo $entry.path
    if (Test-Path -LiteralPath $old) {
      $existing += $entry.path
      $dest = Join-Path $backup $entry.path
      New-Item -ItemType Directory -Path (Split-Path -Parent $dest) -Force | Out-Null
      Copy-Item -LiteralPath $old -Destination $dest -Force
    }
  }
  $existing | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $backup 'EXISTING_FILES.json') -Encoding UTF8
  [IO.File]::WriteAllText((Join-Path $env:USERPROFILE 'Downloads\Zameel_Update_142_Path.txt'), $update)
  Write-Host "APP extracted and verified: $($manifest.files.Count) files"
  Write-Host "Changed-file backup: $backup"
  Write-Host "Update root: $update"
  return
}
if (-not $UpdateRoot -or -not (Test-Path -LiteralPath $UpdateRoot)) { throw 'Supply -UpdateRoot from Prepare' }
$root = Join-Path $UpdateRoot 'APP'
$manifest = Read-Manifest $root
if ($Stage -eq 'Copy') {
  foreach ($entry in $manifest.files) {
    $dest = Join-Path $AppRepo $entry.path
    if ($entry.base_sha256 -and (Test-Path -LiteralPath $dest)) {
      $hash = Get-TextHash $dest
      if ($hash -ne $entry.base_sha256 -and $hash -ne $entry.text_sha256) { throw "Existing file differs from release 141; stopped: $($entry.path)" }
    }
  }
  foreach ($entry in $manifest.files) {
    $dest = Join-Path $AppRepo $entry.path
    New-Item -ItemType Directory -Path (Split-Path -Parent $dest) -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $root $entry.path) -Destination $dest -Force
    if ((Get-FileHash -LiteralPath $dest -Algorithm SHA256).Hash -ne $entry.sha256) { throw "Copy mismatch: $($entry.path)" }
  }
  Copy-Item -LiteralPath (Join-Path $root 'UPDATE_142_MANIFEST.json') -Destination (Join-Path $AppRepo 'UPDATE_142_MANIFEST.json') -Force
  Write-Host "APP copied and verified: $($manifest.files.Count) files"
  return
}
foreach ($entry in $manifest.files) {
  if ((Get-TextHash (Join-Path $AppRepo $entry.path)) -ne $entry.text_sha256) { throw "Run Copy first; file differs: $($entry.path)" }
}
if ($Stage -eq 'Sql1' -or $Stage -eq 'Sql2') {
  $name = if ($Stage -eq 'Sql1') { '20261005223001_142_immediate_call_push.sql' } else { '20261005223002_142_android_release.sql' }
  Get-Content -LiteralPath (Join-Path $AppRepo "supabase\migrations\$name") -Raw -Encoding UTF8 | Set-Clipboard
  Write-Host 'SQL copied. Paste into Supabase SQL Editor and run there.'
  return
}
Push-Location -LiteralPath $AppRepo
try {
  if ($Stage -eq 'Check') {
    flutter pub get; Assert-Exit 'Dependency resolution failed'
    flutter analyze; Assert-Exit 'Flutter analysis failed'
    flutter test --no-pub; Assert-Exit 'Flutter tests failed'
    node --test verification/call_push_142_test.mjs; Assert-Exit 'Call push tests failed'
    Write-Host 'Checks passed. Android build on GitHub only; no ADMIN executable update.'
    return
  }
  if ($Stage -eq 'DeployFunction') {
    npx supabase functions deploy send-push-notifications --project-ref jwuqyykjmltroneqtjoc --no-verify-jwt
    Assert-Exit 'Push function deployment failed'
    Write-Host 'Push function deployed. Calls require the private webhook secret.'
    return
  }
  $files = @($manifest.files | ForEach-Object { $_.path }) + @('UPDATE_142_MANIFEST.json')
  $staged = @(git diff --cached --name-only); Assert-Exit 'Cannot inspect staging'
  if (@($staged | Where-Object { $_ -notin $files }).Count -gt 0) { throw 'Staged changes outside patch; review first' }
  $branch = git branch --show-current; Assert-Exit 'Cannot read branch'
  if ($branch -ne 'main') { throw 'Expected main branch' }
  git fetch origin main; Assert-Exit 'Fetch failed'
  git merge-base --is-ancestor origin/main HEAD; Assert-Exit 'Branch behind or diverged; review first'
  git add -- $files; Assert-Exit 'Git add failed'
  git diff --cached --check; Assert-Exit 'Staged diff check failed'
  git diff --cached --stat
  git diff --cached --quiet
  if ($LASTEXITCODE -eq 1) {
    git commit -m 'Add immediate Android incoming calls and direct notification navigation'
    Assert-Exit 'Commit failed'
  } elseif ($LASTEXITCODE -ne 0) { throw 'Cannot inspect staged diff' }
  git push origin main; Assert-Exit 'Push failed'
  git status --short --branch
} finally { Pop-Location }
