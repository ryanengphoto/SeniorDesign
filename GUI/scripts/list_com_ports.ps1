# List Windows COM ports (CP2102 / FTDI / etc.). Run in PowerShell on Windows.
# Usage (from GUI/):  .\scripts\list_com_ports.ps1

$ErrorActionPreference = "Continue"

Write-Host "COM ports (registry):"
$regPath = "HKLM:\HARDWARE\DEVICEMAP\SERIALCOMM"
if (Test-Path $regPath) {
    $props = Get-ItemProperty -Path $regPath
    foreach ($p in $props.PSObject.Properties) {
        if ($p.Name -like "PS*") { continue }
        Write-Host ("  {0}" -f $p.Value)
    }
} else {
    Write-Host "  (none)"
}

Write-Host ""
Write-Host "PnP devices mentioning COM:"
Get-CimInstance Win32_PnPEntity -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match '\(COM\d+\)' } |
    ForEach-Object { Write-Host ("  " + $_.Name) }

Write-Host ""
Write-Host "Tier-2 (cross-wired CP2102s — dummy mcu_sim, not PCB):"
Write-Host '  python scripts\mcu_sim.py --port COM3 -i'
Write-Host '  .\scripts\run_windows_serial.ps1 -Port COM4'
