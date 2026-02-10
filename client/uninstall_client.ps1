Write-Host ">>> YemekBildirimi Uninstaller <<<"

$TaskName = "YemekBildirimiClient"
$Target = Join-Path $env:LOCALAPPDATA "YemekBildirimi"

# 1) Remove Scheduled Task
Write-Host "[*] Removing Scheduled Task..."
schtasks /Delete /TN "\$TaskName" /F 2>$null | Out-Null

# 2) Remove installation directory
if (Test-Path $Target) {
    Write-Host "[*] Removing installation directory: $Target"
    Remove-Item $Target -Recurse -Force -ErrorAction SilentlyContinue
}

# 3) Legacy cleanup (if user wants to remove old backup)
$Old2 = Join-Path $env:LOCALAPPDATA "YemekBildirimi_old"
if (Test-Path $Old2) {
    $response = Read-Host "Old backup found at $Old2. Delete? (y/N)"
    if ($response -eq "y" -or $response -eq "Y") {
        Remove-Item $Old2 -Recurse -Force
        Write-Host "[*] Old backup removed."
    }
}

Write-Host "[+] Uninstallation complete!"
Write-Host "    Note: BurntToast module was NOT removed (may be used by other apps)."
