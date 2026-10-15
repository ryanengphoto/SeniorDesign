# Run Flutter Windows desktop with in-process mock hub (no COM / usbipd).
# Usage (from GUI/):  .\scripts\run_windows_mock.ps1

param(
    [ValidateSet("debug", "release", "profile")]
    [string]$Mode = "debug"
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$App = Join-Path $Root "app"

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Error "flutter not found on PATH. Install Flutter for Windows and reopen PowerShell."
}

Set-Location $App
flutter pub get
flutter run -d windows --$Mode --dart-define=HUB_MODE=mock
