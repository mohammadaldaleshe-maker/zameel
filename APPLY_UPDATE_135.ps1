param(
  [ValidateSet('Prepare','Copy','Check','DeployFunction','CommitApp','CommitAdmin')]
  [string]$Stage = 'Prepare',
  [string]$UpdateRoot = '',
  [string]$AppRepo = (Join-Path $env:USERPROFILE 'Desktop\2027\zameel-feature-control'),
  [string]$AdminRepo = (Join-Path $env:USERPROFILE 'Desktop\لوحة التحكم\zameel-admin-feature-control')
)
$ErrorActionPreference = 'Stop'
function Assert-Exit([string]$Message) { if ($LASTEXITCODE -ne 0) { throw $Message } }
function Read-UpdateManifest([string]$RepoStage) {
  $manifestPath = Join-Path $RepoStage 'UPDATE_135_MANIFEST.json'
  $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
  if ($manifest.release -ne 135 -or $manifest.files.Count -lt 1) { throw 'Invalid release manifest' }
  foreach ($entry in $manifest.files) {
    if ($entry.path -match '(^/|^[A-Za-z]:|(^|[/\\])\.\.([/\\]|$)|(^|[/\\])\.git([/\\]|$))') { throw 'Unsafe manifest path' }
    $source = Join-Path $RepoStage $entry.path
    if ((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash -ne $entry.sha256) { throw "Source hash mismatch: $($entry.path)" }
  }
  return $manifest
}
$repositories = @(
  @{ Name = 'APP'; Path = $AppRepo; Remote = 'https://github.com/mohammadaldaleshe-maker/zameel.git' },
  @{ Name = 'ADMIN'; Path = $AdminRepo; Remote = 'https://github.com/mohammadaldaleshe-maker/zameel-admin-windows.git' }
)
foreach ($repo in $repositories) {
  if (-not (Test-Path -LiteralPath $repo.Path -PathType Container)) { throw "Repository not found: $($repo.Path)" }
  $remote = git -C $repo.Path remote get-url origin
  Assert-Exit 'Cannot read Git remote'
  if ($remote.TrimEnd('/') -ne $repo.Remote) { throw "Unexpected repository remote: $remote" }
}
if ($Stage -eq 'Prepare') {
  $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
  $backup = Join-Path $env:USERPROFILE "Desktop\Zameel_Backup_Before_135_$stamp"
  $update = Join-Path $env:USERPROFILE "Desktop\Zameel_Update_135_$stamp"
  foreach ($repo in $repositories) {
    robocopy $repo.Path (Join-Path $backup $repo.Name) /E /COPY:DAT /DCOPY:DAT /R:1 /W:1 /XD .git .dart_tool build node_modules .gradle target /NFL /NDL /NP /NJH /NJS
    if ($LASTEXITCODE -ge 8) { throw "Backup failed: $($repo.Name)" }
  }
  New-Item -ItemType Directory -Path $update | Out-Null
  Expand-Archive -LiteralPath (Join-Path $env:USERPROFILE 'Downloads\Zameel_APP_135_MAINTENANCE_PROMOTIONS.zip') -DestinationPath (Join-Path $update 'APP')
  Expand-Archive -LiteralPath (Join-Path $env:USERPROFILE 'Downloads\Zameel_ADMIN_135_WALLET_TARGETING.zip') -DestinationPath (Join-Path $update 'ADMIN')
  foreach ($repo in $repositories) {
    $manifest = Read-UpdateManifest (Join-Path $update $repo.Name)
    Write-Host "$($repo.Name) extracted and verified: $($manifest.files.Count) update files"
  }
  Write-Host "Backup completed: $backup"
  Write-Host "Update root: $update"
  return
}
if (-not $UpdateRoot -or -not (Test-Path -LiteralPath $UpdateRoot)) { throw 'Supply -UpdateRoot from the Prepare stage' }
if ($Stage -eq 'Copy') {
  foreach ($repo in $repositories) {
    $sourceRoot = Join-Path $UpdateRoot $repo.Name
    $manifest = Read-UpdateManifest $sourceRoot
    foreach ($entry in $manifest.files) {
      $destination = Join-Path $repo.Path $entry.path
      New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
      Copy-Item -LiteralPath (Join-Path $sourceRoot $entry.path) -Destination $destination -Force
      if ((Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash -ne $entry.sha256) { throw "Copy verification failed: $($entry.path)" }
    }
    Copy-Item -LiteralPath (Join-Path $sourceRoot 'UPDATE_135_MANIFEST.json') -Destination (Join-Path $repo.Path 'UPDATE_135_MANIFEST.json') -Force
    Write-Host "$($repo.Name) update copied and verified: $($manifest.files.Count) files"
  }
  return
}
if ($Stage -eq 'Check') {
  Push-Location -LiteralPath $AppRepo
  try {
    flutter pub get; Assert-Exit 'Flutter dependencies failed'
    flutter analyze; Assert-Exit 'Flutter analysis failed'
    flutter test; Assert-Exit 'Flutter tests failed'
  } finally { Pop-Location }
  Push-Location -LiteralPath $AdminRepo
  try {
    npm ci; Assert-Exit 'Admin dependencies failed'
    node --test test/*.mjs; Assert-Exit 'Admin tests failed'
    npm run bundle:web; Assert-Exit 'Admin web bundle failed'
  } finally { Pop-Location }
  Write-Host 'APP and ADMIN checks passed'
  return
}
if ($Stage -eq 'DeployFunction') {
  Push-Location -LiteralPath $AdminRepo
  try { npx supabase functions deploy admin-console --project-ref jwuqyykjmltroneqtjoc; Assert-Exit 'Function deployment failed' } finally { Pop-Location }
  return
}
$repo = if ($Stage -eq 'CommitApp') { $repositories[0] } else { $repositories[1] }
$manifest = Read-UpdateManifest (Join-Path $UpdateRoot $repo.Name)
$files = @($manifest.files | ForEach-Object { $_.path }) + @('UPDATE_135_MANIFEST.json')
$staged = @(git -C $repo.Path diff --cached --name-only)
Assert-Exit 'Cannot inspect staged changes'
if ($staged.Count -gt 0) { throw 'Existing staged changes found. Review them before staging release 135.' }
$branch = git -C $repo.Path branch --show-current
Assert-Exit 'Cannot read current branch'
if ($branch -ne 'main') { throw 'Expected main branch' }
git -C $repo.Path fetch origin main; Assert-Exit 'Git fetch failed'
git -C $repo.Path merge-base --is-ancestor origin/main HEAD; Assert-Exit 'Local main is behind or diverged; review remote changes first'
git -C $repo.Path add -- $files; Assert-Exit 'Git add failed'
git -C $repo.Path diff --cached --check; Assert-Exit 'Staged diff check failed'
git -C $repo.Path diff --cached --stat
$message = if ($repo.Name -eq 'APP') { 'Improve typography, profile cropping and targeted wallet promotions' } else { 'Add manual wallet reconciliation and targeted promotion administration' }
git -C $repo.Path commit -m $message; Assert-Exit 'Git commit failed'
git -C $repo.Path push origin main; Assert-Exit 'Git push failed'
git -C $repo.Path status --short --branch
