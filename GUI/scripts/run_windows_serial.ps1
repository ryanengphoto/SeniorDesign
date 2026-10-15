# Run Flutter Windows desktop against a real COM port (Tier-2 CP2102 / future MCU).
# Keeps the WSL/Linux path intact — use this on Windows instead of usbipd.
#
# Prerequisites (Windows host, not WSL):
#   - Flutter for Windows + Visual Studio "Desktop development with C++"
#   - Silicon Labs CP210x VCP drivers
#   - Cross-wired pair: TX↔RX, GND↔GND; both plugged into the PC
#   - pyserial for mcu_sim:  pip install pyserial
#
# Usage (from GUI/ in PowerShell):
#   .\scripts\list_com_ports.ps1
#   # Terminal A:
#   python scripts\mcu_sim.py --port COM3 -i
#   # Terminal B:
#   .\scripts\run_windows_serial.ps1 -Port COM4
#
# Mock (no serial):  .\scripts\run_windows_mock.ps1

param(
    [Parameter(Mandatory = $true)]
    [string]$Port,

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

# Normalize COM10+ for Win32 CreateFile (\\.\COMn).
$serialPort = $Port.Trim()
if ($serialPort -match '^(?i)COM(\d+)$') {
    $n = [int]$Matches[1]
    if ($n -ge 10) {
        $serialPort = "\\.\COM$n"
    } else {
        $serialPort = "COM$n"
    }
}

Write-Host "HUB_MODE=serial  SERIAL_PORT=$serialPort  SERIAL_BAUD=$Baud"
Write-Host "Dummy peer is mcu_sim on the other COM — not carrier PCB / STM32."
Write-Host ""

Set-Location $App
flutter pub get
flutter run -d windows `
    --$Mode `
    --dart-define=HUB_MODE=serial `
    --dart-define=SERIAL_PORT=$serialPort `
    --dart-define=SERIAL_BAUD=$Baud
