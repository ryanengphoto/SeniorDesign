# Build a portable Windows Release folder for the operator console.
# Run on Windows with Flutter on PATH and Visual Studio "Desktop development with C++".
#
# Usage (from GUI/):
#   .\scripts\build_windows.ps1
#
# Zip the printed Release folder to hand out a portable demo (exe + DLLs).

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$App = Join-Path $Root "app"

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Error "flutter not found on PATH. Install Flutter for Windows and reopen this shell."
}

Set-Location $App
flutter pub get
flutter build windows --release

$Release = Join-Path $App "build\windows\x64\runner\Release"
Write-Host ""
Write-Host "Portable package folder:"
Write-Host "  $Release"
Write-Host ""
Write-Host "Zip that entire folder (hub_console.exe + DLLs + data/). Do not ship the .exe alone."
