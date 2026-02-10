param(
    [string]$ServerUrl = "https://yemek.example.com",
    [int]$PollingInterval = 5
)

Write-Host ">>> YemekBildirimi Installer (Scheduled Task) <<<"

$Source = $PSScriptRoot
$Target = Join-Path $env:LOCALAPPDATA "YemekBildirimi"
$TaskName = "YemekBildirimiClient"

Write-Host "Source: $Source"
Write-Host "Target: $Target"
Write-Host "Server: $ServerUrl"
Write-Host "Interval: ${PollingInterval}s"

# 1) Kopyala
New-Item -Force -ItemType Directory $Target | Out-Null
Write-Host "[*] Copying files..."
$cmd = "robocopy `"$Source`" `"$Target`" /E /R:2 /W:2"
cmd /c $cmd | Out-Null

# 2) Legacy: eski kurulum klasörü (USERPROFILE\YemekBildirimi) varsa taşı
$Old1 = Join-Path $env:USERPROFILE "YemekBildirimi"
$Old2 = Join-Path $env:LOCALAPPDATA "YemekBildirimi_old"
if (Test-Path $Old1) {
    Write-Host "[*] Old install found: $Old1 -> moving to $Old2"
    Remove-Item $Old2 -Recurse -Force -ErrorAction SilentlyContinue
    Move-Item $Old1 $Old2 -Force
}

# 3) Legacy: eski Startup VBS varsa kaldır (artık Task kullanıyoruz)
$Vbs = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Startup\YemekBildirimiClient.vbs"
Remove-Item $Vbs -Force -ErrorAction SilentlyContinue

# 4) Legacy: eski Scheduled Task varsa sil
Write-Host "[*] Removing legacy scheduled task (if any)..."
schtasks /Delete /TN "\$TaskName" /F 2>$null | Out-Null

# 5) Scheduled Task oluştur
Write-Host "[*] Creating Scheduled Task..."
$ClientPs = Join-Path $Target "client.ps1"
$TR = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$ClientPs`" -Server `"$ServerUrl`" -PollingInterval $PollingInterval"

schtasks /Create /F /TN "\$TaskName" /SC ONLOGON /DELAY 0000:10 /TR "$TR" | Out-Null

# 6) Hemen başlat
schtasks /Run /TN "\$TaskName" | Out-Null

Write-Host "[+] Installation Complete!"
Write-Host "    Logs: $Target\client.log"
Write-Host "    Task: \${TaskName} (ONLOGON)"
