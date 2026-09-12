$ErrorActionPreference = 'Stop'

Write-Host '== Zameel release build ==' -ForegroundColor Cyan
flutter clean
flutter pub get
flutter analyze
flutter test

if (!(Test-Path 'android/key.properties')) {
  throw 'android/key.properties is missing. Create it from android/key.properties.example before a production release.'
}

flutter build appbundle --release
Write-Host 'Release AAB:' -ForegroundColor Green
Get-ChildItem 'build/app/outputs/bundle/release/' -Filter '*.aab' | Select-Object FullName,Length
