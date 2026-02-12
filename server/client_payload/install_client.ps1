param(
  [Parameter(Mandatory = $true)]
  [string]$ServerUrl,

  [int]$PollingInterval = 5,

  [string]$InstallDir = "$env:LOCALAPPDATA\YemekBildirimi",

  [string]$TaskName = "YemekBildirimiClient"
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

Write-Host ">>> YemekBildirimi Client Installer (Current User) <<<"
Write-Host "ServerUrl: $ServerUrl"
Write-Host "PollingInterval: $PollingInterval"
Write-Host "InstallDir: $InstallDir"
Write-Host "TaskName: $TaskName"

if ($PollingInterval -lt 1 -or $PollingInterval -gt 3600) { $PollingInterval = 5 }
$ServerUrl = $ServerUrl.TrimEnd("/")

function Try-StopExistingTask {
  try {
    $t = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($t) {
      Write-Host "[*] Existing scheduled task found. Removing..."
      try { Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue } catch {}
      Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    }
  } catch {
    Write-Warning "ScheduledTask cleanup failed: $($_.Exception.Message)"
  }
}

function Try-StopRunningClient {
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
  } catch {
    Write-Warning "Process stop failed: $($_.Exception.Message)"
  }
}

function Ensure-InstallDir {
  if (-not (Test-Path -LiteralPath $InstallDir)) {
    New-Item -Path $InstallDir -ItemType Directory -Force | Out-Null
  }
}

function Copy-ClientFiles {
  param([string]$SourcePath)

  Ensure-InstallDir

  Write-Host "[*] Copying client files..."
  try {
    robocopy $SourcePath $InstallDir /E /R:2 /W:2 /NJH /NJS /NFL /NDL | Out-Null
    if ($LASTEXITCODE -gt 7) { throw "Robocopy failed with exit code $LASTEXITCODE" }
  } catch {
    Write-Warning "Robocopy failed, falling back to Copy-Item: $($_.Exception.Message)"
    Copy-Item -Path (Join-Path $SourcePath '*') -Destination $InstallDir -Recurse -Force
  }

  $clientPs1 = Join-Path $InstallDir "client.ps1"
  if (-not (Test-Path -LiteralPath $clientPs1)) {
    throw "CRITICAL: client.ps1 not found after copy."
  }

  # ---- Guarantee assets/logo.png exists if shipped ----
  $srcLogo = Join-Path $SourcePath "assets\logo.png"
  $dstLogo = Join-Path $InstallDir "assets\logo.png"
  if ((Test-Path -LiteralPath $srcLogo) -and (-not (Test-Path -LiteralPath $dstLogo))) {
    Write-Host "[*] assets missing after copy, forcing logo copy..."
    New-Item -Path (Split-Path $dstLogo -Parent) -ItemType Directory -Force | Out-Null
    Copy-Item -LiteralPath $srcLogo -Destination $dstLogo -Force
  }
}

function Write-Config {
  $cfg = @{
    ServerUrl       = $ServerUrl
    PollingInterval = $PollingInterval
  } | ConvertTo-Json -Depth 3

  $cfgPath = Join-Path $InstallDir "config.json"
  $cfg | Out-File -FilePath $cfgPath -Encoding UTF8 -Force
  Write-Host "[*] Config written: $cfgPath"
}

function Ensure-BurntToast {
  try {
    if (-not (Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue)) {
      Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser | Out-Null
    }
    if (-not (Get-Module -ListAvailable -Name BurntToast)) {
      Install-Module -Name BurntToast -Scope CurrentUser -Force -AllowClobber -SkipPublisherCheck
    }
  } catch {
    Write-Warning "BurntToast install skipped: $($_.Exception.Message)"
  }
}

function Remove-StartupFallback {
  try {
    $startupDir = [Environment]::GetFolderPath("Startup")
    $vbsPath = Join-Path $startupDir "YemekBildirimiClient.vbs"
    if (Test-Path $vbsPath) { Remove-Item $vbsPath -Force }
  } catch {}
}

function Install-ScheduledTaskOrFallback {
  $clientPs1 = Join-Path $InstallDir "client.ps1"

  $arg = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$clientPs1`""
  $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $arg
  $trigger = New-ScheduledTaskTrigger -AtLogOn
  $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances IgnoreNew

  try {
    # Compatibility: LogonType / RunLevel enum differs by Windows versions
    $principal = $null
    try {
      $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited
    } catch {
      $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive
    }

    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force | Out-Null
    Start-ScheduledTask -TaskName $TaskName
    Write-Host "[+] Scheduled Task installed & started."
    return
  } catch {
    Write-Warning "ScheduledTask failed: $($_.Exception.Message)"
  }

  # Fallback: Startup VBS
  try {
    $startupDir = [Environment]::GetFolderPath("Startup")
    $vbsPath = Join-Path $startupDir "YemekBildirimiClient.vbs"

    $escaped = $clientPs1.Replace('"','""')
    $vbs = @"
Set WshShell = CreateObject("WScript.Shell")
WshShell.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""$escaped""", 0, False
"@
    $vbs | Out-File -FilePath $vbsPath -Encoding ascii -Force
    Write-Host "[+] Startup fallback installed: $vbsPath"
  } catch {
    throw "Both ScheduledTask and Startup fallback failed: $($_.Exception.Message)"
  }
}

# ---- MAIN ----
Try-StopExistingTask
Try-StopRunningClient
Remove-StartupFallback
Ensure-BurntToast

$source = $PSScriptRoot
Copy-ClientFiles -SourcePath $source
Write-Config
Install-ScheduledTaskOrFallback

Write-Host "[+] Done."
Write-Host "Logs: $(Join-Path $InstallDir 'client.log')"
