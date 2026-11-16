# Run Flutter Windows desktop in serial mode.
# COM port is optional — pick it live in the app header dropdown.
#
# Prerequisites (Windows host, not WSL):
#   - Flutter for Windows + Visual Studio "Desktop development with C++"
#   - Silicon Labs CP210x VCP drivers (for CP2102 / Black Pill UART)
#
# Usage (from GUI/ in PowerShell):
#   .\scripts\run_windows_serial.ps1
#   .\scripts\run_windows_serial.ps1 -Port COM3   # optional preselect
#
# Mock (no serial):  .\scripts\run_windows_mock.ps1

param(
    [string]$Port = "",

    [int]$Baud = 115200,

    [ValidateSet("debug", "release", "profile")]
    [string]$Mode = "debug"
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$App = Join-Path $Root "app"

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Error "flutter not found on PATH. Install Flutter for Windows and reopen PowerShell."
}

$defines = @(
    "--dart-define=HUB_MODE=serial",
    "--dart-define=SERIAL_BAUD=$Baud"
)

$serialPort = $Port.Trim()
if ($serialPort -ne "") {
    # Normalize COM10+ for Win32 CreateFile (\\.\COMn).
    if ($serialPort -match '^(?i)COM(\d+)$') {
        $n = [int]$Matches[1]
        if ($n -ge 10) {
            $serialPort = "\\.\COM$n"
        } else {
            $serialPort = "COM$n"
        }
    }
    $defines += "--dart-define=SERIAL_PORT=$serialPort"
    Write-Host "HUB_MODE=serial  SERIAL_PORT=$serialPort  SERIAL_BAUD=$Baud"
} else {
    Write-Host "HUB_MODE=serial  SERIAL_PORT=(pick in UI)  SERIAL_BAUD=$Baud"
}

Write-Host "Peer may be mcu_sim (dummy) OR Black Pill Firmware/ UART stub."
Write-Host "Use the header COM dropdown to select/change ports without restarting."
Write-Host ""

Set-Location $App
flutter pub get
flutter run -d windows --$Mode @defines
