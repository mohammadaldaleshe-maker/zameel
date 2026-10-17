param(
  [ValidateSet('Prepare','Copy','Check','Sql1','Sql2','CommitApp','CommitAdmin')]
  [string]$Stage = 'Prepare',
  [string]$UpdateRoot = '',
  [string]$AppRepo = (Join-Path $env:USERPROFILE 'Desktop\2027\zameel-feature-control'),
  [string]$AdminRepo = (Join-Path $env:USERPROFILE 'Desktop\لوحة التحكم\zameel-admin-feature-control')
)
$ErrorActionPreference = 'Stop'
function Assert-Exit([string]$Message) { if ($LASTEXITCODE -ne 0) { throw $Message } }
function Read-UpdateManifest([string]$RepoStage) {
  $manifestPath = Join-Path $RepoStage 'UPDATE_140_MANIFEST.json'
  $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
  if ($manifest.release -ne 140 -or $manifest.files.Count -lt 1) { throw 'Invalid release manifest' }
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
  $backup = Join-Path $env:USERPROFILE "Desktop\Zameel_Backup_Before_140_$stamp"
  $update = Join-Path $env:USERPROFILE "Desktop\Zameel_Update_140_$stamp"
  foreach ($repo in $repositories) {
    $destination = Join-Path $backup $repo.Name
    New-Item -ItemType Directory -Path $backup -Force | Out-Null
    $logPath = Join-Path $backup ("Backup_" + $repo.Name + ".log")
    Write-Host "Starting backup: $($repo.Name). Progress will print every 15 seconds."
    $sourceArg = '"' + $repo.Path + '"'
    $destinationArg = '"' + $destination + '"'
    $logArg = '/UNILOG:"' + $logPath + '"'
    $backupArgs = @($sourceArg, $destinationArg, '/E','/COPY:DAT','/DCOPY:DAT','/R:1','/W:1','/XJ','/XD','.git','.dart_tool','build','node_modules','.gradle','target','/NFL','/NDL','/NP','/NJH','/NJS', $logArg)
    $copyProcess = Start-Process -FilePath 'robocopy.exe' -ArgumentList $backupArgs -NoNewWindow -PassThru
    $backupWatch = [Diagnostics.Stopwatch]::StartNew()
    while (-not $copyProcess.WaitForExit(15000)) {
      Write-Host "$($repo.Name) backup running: $([int]$backupWatch.Elapsed.TotalSeconds) seconds"
    }
    $copyProcess.WaitForExit()
    if ($copyProcess.ExitCode -ge 8) { throw "Backup failed: $($repo.Name). See $logPath" }
    Write-Host "$($repo.Name) backup completed."
  }
  New-Item -ItemType Directory -Path $update | Out-Null
  Expand-Archive -LiteralPath (Join-Path $env:USERPROFILE 'Downloads\Zameel_APP_140_SHORTS_CACHE_FIX.zip') -DestinationPath (Join-Path $update 'APP')
  Expand-Archive -LiteralPath (Join-Path $env:USERPROFILE 'Downloads\Zameel_ADMIN_140_SHORTS_LATEST.zip') -DestinationPath (Join-Path $update 'ADMIN')
  foreach ($repo in $repositories) {
    $manifest = Read-UpdateManifest (Join-Path $update $repo.Name)
    Write-Host "$($repo.Name) extracted and verified: $($manifest.files.Count) update files"
  }
  Write-Host "Backup completed: $backup"
  [IO.File]::WriteAllText((Join-Path $env:USERPROFILE 'Downloads\Zameel_Update_140_Path.txt'), $update)
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
    Copy-Item -LiteralPath (Join-Path $sourceRoot 'UPDATE_140_MANIFEST.json') -Destination (Join-Path $repo.Path 'UPDATE_140_MANIFEST.json') -Force
    Write-Host "$($repo.Name) update copied and verified: $($manifest.files.Count) files"
  }
  return
}
if ($Stage -eq 'Check') {
  Push-Location -LiteralPath $AppRepo
  try {
    Write-Host 'APP: resolving dependencies'
    flutter pub get; Assert-Exit 'Flutter dependencies failed'
    Write-Host 'APP: analyzing source'
    flutter analyze; Assert-Exit 'Flutter analysis failed'
    Write-Host 'APP: running complete test suite'
    flutter test --no-pub; Assert-Exit 'Flutter tests failed'
  } finally { Pop-Location }
  Write-Host 'ADMIN: SQL/catalog only; executable is unchanged.'
  Write-Host 'APP checks passed. Android build runs on GitHub only.'
  return
}
if ($Stage -eq 'Sql1') {
  Get-Content -LiteralPath (Join-Path $AdminRepo 'supabase\migrations\20261005063001_140_shorts_latest.sql') -Raw -Encoding UTF8 | Set-Clipboard
  Write-Host 'SQL 140 copied. Paste clipboard CONTENT in Supabase SQL Editor.'
  return
}
if ($Stage -eq 'Sql2') {
  Get-Content -LiteralPath (Join-Path $AdminRepo 'supabase\migrations\20261005063002_140_android_release.sql') -Raw -Encoding UTF8 | Set-Clipboard
  Write-Host 'SQL release catalog copied. Paste clipboard CONTENT in Supabase SQL Editor.'
  return
}
$repo = if ($Stage -eq 'CommitApp') { $repositories[0] } else { $repositories[1] }
$manifest = Read-UpdateManifest (Join-Path $UpdateRoot $repo.Name)
$files = @($manifest.files | ForEach-Object { $_.path }) + @('UPDATE_140_MANIFEST.json')
$staged = @(git -C $repo.Path diff --cached --name-only)
Assert-Exit 'Cannot inspect staged changes'
$unexpected = @($staged | Where-Object { $_ -notin $files })
if ($unexpected.Count -gt 0) { $unexpected; throw 'Staged files outside update 140 found. Review them first.' }
# Release-only staged files from a failed check are safe to restage.
$branch = git -C $repo.Path branch --show-current
Assert-Exit 'Cannot read current branch'
if ($branch -ne 'main') { throw 'Expected main branch' }
git -C $repo.Path fetch origin main; Assert-Exit 'Git fetch failed'
git -C $repo.Path merge-base --is-ancestor origin/main HEAD; Assert-Exit 'Local main is behind or diverged; review remote changes first'
git -C $repo.Path add -- $files; Assert-Exit 'Git add failed'
git -C $repo.Path diff --cached --check; Assert-Exit 'Staged diff check failed'
git -C $repo.Path diff --cached --stat
git -C $repo.Path diff --cached --quiet
if ($LASTEXITCODE -eq 0) { git -C $repo.Path push origin main; Assert-Exit 'Git push failed'; git -C $repo.Path status --short --branch; return }
if ($LASTEXITCODE -ne 1) { throw 'Cannot inspect staged diff' }
$message = if ($repo.Name -eq 'APP') { 'Repair Shorts previews, latest ordering, composer contrast and bounded background cache' } else { 'Order Shorts by newest and register Android 2.0.6' }
git -C $repo.Path commit -m $message; Assert-Exit 'Git commit failed'
git -C $repo.Path push origin main; Assert-Exit 'Git push failed'
git -C $repo.Path status --short --branch
