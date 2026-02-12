param(
  [string]$ServerUrl = $null,
  [int]$PollingInterval = 5
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$BaseDir = Join-Path $env:LOCALAPPDATA "YemekBildirimi"
if (-not (Test-Path $BaseDir)) { New-Item -Path $BaseDir -ItemType Directory -Force | Out-Null }

$LogPath = Join-Path $BaseDir "client.log"
$StatePath = Join-Path $BaseDir "state.json"
$ConfigPath = Join-Path $BaseDir "config.json"

function Write-Log([string]$Level, [string]$Msg) {
  $ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
  "$ts [$Level] $Msg" | Out-File -FilePath $LogPath -Append -Encoding UTF8
}

function Rotate-Log {
  try {
    if (Test-Path $LogPath) {
      $len = (Get-Item $LogPath).Length
      if ($len -gt 1048576) { # 1MB
        $bak = Join-Path $BaseDir ("client_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".log")
        Move-Item $LogPath $bak -Force
      }
    }
  } catch {}
}

Rotate-Log
Write-Log "INFO" "Starting YemekBildirimi Client..."

# ---- Load config.json (preferred) ----
if ((-not $ServerUrl) -and (Test-Path $ConfigPath)) {
  try {
    $cfg = Get-Content $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($cfg.ServerUrl) { $ServerUrl = [string]$cfg.ServerUrl }
    if ($cfg.PollingInterval) { $PollingInterval = [int]$cfg.PollingInterval }
  } catch {
    Write-Log "WARN" "Config parse failed: $($_.Exception.Message)"
  }
}

if ([string]::IsNullOrWhiteSpace($ServerUrl)) {
  Write-Log "ERROR" "ServerUrl not set (param or config.json). Exiting."
  exit 2
}

if ($PollingInterval -lt 1 -or $PollingInterval -gt 3600) { $PollingInterval = 5 }

# Normalize base URL
$ServerUrl = $ServerUrl.TrimEnd("/")

# ---- Single instance (Local mutex) ----
$mutexName = "Local\YemekBildirimiClient"
$createdNew = $false
$mutex = New-Object System.Threading.Mutex($true, $mutexName, [ref]$createdNew)
if (-not $createdNew) {
  Write-Log "WARN" "Another instance is already running. Exiting."
  exit 0
}

# ---- Load last seen id ----
$lastSeen = 0
if (Test-Path $StatePath) {
  try {
    $st = Get-Content $StatePath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($st.last_seen_id) { $lastSeen = [int]$st.last_seen_id }
  } catch {}
}

function Save-State([int]$id) {
  try {
    @{ last_seen_id = $id } | ConvertTo-Json | Out-File -FilePath $StatePath -Encoding UTF8 -Force
  } catch {}
}

# ---- Toast (BurntToast) ----
$toastReady = $false
try {
  Import-Module BurntToast -ErrorAction Stop
  $toastReady = $true
} catch {
  $toastReady = $false
  Write-Log "WARN" "BurntToast not available. Notifications will be skipped."
}

function Show-Toast([string]$text) {
  if (-not $toastReady) { return }
  try {
    New-BurntToastNotification -Text "🍽️ Yemek Bildirimi", $text | Out-Null
  } catch {
    Write-Log "WARN" "Toast failed: $($_.Exception.Message)"
  }
}

# ---- Poll loop ----
Add-Type -AssemblyName System.Net.Http
$handler = New-Object System.Net.Http.HttpClientHandler
$client = New-Object System.Net.Http.HttpClient($handler)
$client.Timeout = [TimeSpan]::FromSeconds(10)

$latestUrl = "$ServerUrl/latest"

while ($true) {
  try {
    $resp = $client.GetAsync($latestUrl).Result
    if (-not $resp.IsSuccessStatusCode) {
      Write-Log "WARN" "HTTP $([int]$resp.StatusCode) calling /latest"
      Start-Sleep -Seconds $PollingInterval
      continue
    }

    $body = $resp.Content.ReadAsStringAsync().Result
    $data = $body | ConvertFrom-Json

    $id = [int]$data.id
    $text = [string]$data.text

    if ($id -gt $lastSeen) {
      $lastSeen = $id
      Save-State -id $lastSeen
      Write-Log "INFO" "New notification: ID=$id Text=$text"
      Show-Toast -text $text
    }
  } catch {
    Write-Log "WARN" "Poll error: $($_.Exception.Message)"
  }

  Start-Sleep -Seconds $PollingInterval
}


