param(
  [string]$SecretDirectory = 'D:\ZameelPrivate'
)

$ErrorActionPreference = 'Stop'
$keytool = Get-Command keytool -ErrorAction Stop
New-Item -ItemType Directory -Path $SecretDirectory -Force | Out-Null
$keystore = Join-Path $SecretDirectory 'zameel-upload.jks'
if (Test-Path -LiteralPath $keystore) {
  throw "A keystore already exists at $keystore. Never replace an existing upload key."
}

Write-Host 'Create a strong, unique keystore password and save it securely.'
Write-Host 'When keytool asks for the key password, press Enter to reuse the store password.'
& $keytool.Source -genkeypair -v -keystore $keystore -alias zameel-upload `
  -keyalg RSA -keysize 4096 -validity 10000 `
  -dname 'CN=Zameel Upload, OU=Mobile, O=Zameel, C=JO'
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $keystore)) {
  throw 'Key generation failed.'
}
Write-Host "Upload key saved at $keystore"
Write-Host 'Back up this file and its password separately. Do not commit or share them.'
Write-Host 'To copy the value for GitHub secret ANDROID_KEYSTORE_BASE64:'
Write-Host ('[Convert]::ToBase64String([IO.File]::ReadAllBytes(' + "'" + $keystore + "'" + ')) | Set-Clipboard')
