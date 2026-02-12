Write-Host ">>> YemekBildirimi Uninstaller <<<"

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$TaskName = "YemekBildirimiClient"
$Target = Join-Path $env:LOCALAPPDATA "YemekBildirimi"

function Stop-RunningClient {
  try {
    $procs = Get-CimInstance Win32_Process |
      Where-Object {
        $_.Name -ieq "powershell.exe" -and $_.CommandLine -and
        ($_.CommandLine -like "*client.ps1*" -or $_.CommandLine -like "*YemekBildirimi*")
      }
    foreach ($p in $procs) {
      Write-Host "[*] Stopping running client PID=$($p.ProcessId)"
      Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue
    }
  } catch {}
}

function Remove-StartupFallback {
  try {
    $startupDir = [Environment]::GetFolderPath("Startup")
    $vbsPath = Join-Path $startupDir "YemekBildirimiClient.vbs"
    if (Test-Path -LiteralPath $vbsPath) {
      Write-Host "[*] Removing Startup fallback: $vbsPath"
      Remove-Item -LiteralPath $vbsPath -Force -ErrorAction SilentlyContinue
    }
  } catch {}
}

Write-Host "[*] Stopping running client (if any)..."
Stop-RunningClient

# 1) Remove Scheduled Task
Write-Host "[*] Removing Scheduled Task..."
$removed = $false
try {
  $t = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
  if ($t) {
    try { Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue } catch {}
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    $removed = $true
  }
} catch {}

if (-not $removed) {
  # fallback: schtasks
  try {
    schtasks /Delete /TN "\$TaskName" /F 2>$null | Out-Null
  } catch {}
}

# 2) Remove Startup fallback
Remove-StartupFallback

# 3) Remove installation directory
if (Test-Path -LiteralPath $Target) {
  Write-Host "[*] Removing installation directory: $Target"
  Remove-Item -LiteralPath $Target -Recurse -Force -ErrorAction SilentlyContinue
} else {
  Write-Host "[*] Install directory not found: $Target"
}

# 4) Legacy cleanup (optional)
$Old2 = Join-Path $env:LOCALAPPDATA "YemekBildirimi_old"
if (Test-Path -LiteralPath $Old2) {
  $response = Read-Host "Old backup found at $Old2. Delete? (y/N)"
  if ($response -eq "y" -or $response -eq "Y") {
    Remove-Item -LiteralPath $Old2 -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "[*] Old backup removed."
  }
}

Write-Host "[+] Uninstallation complete!"
Write-Host "    Note: BurntToast module was NOT removed (may be used by other apps)."
