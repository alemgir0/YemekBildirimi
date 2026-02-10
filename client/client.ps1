param(
  # Installer/VBS bu parametreyi geçiyor: -Server "http://x.x.x.x:8787"
  [Parameter(Mandatory=$false)]
  [string]$Server = $null,

  # Opsiyonel: -PollingInterval 5
  [Parameter(Mandatory=$false)]
  [int]$PollingInterval = 5
)

Add-Type -AssemblyName System.Net.Http

# --- 0) Normalize inputs (never allow null to break the loop) ---
if ([string]::IsNullOrWhiteSpace($Server)) {
    # Fallback default (same as server compose exposure)
    $Server = "http://192.168.2.210:8787"
}
if (-not $PollingInterval -or $PollingInterval -lt 1 -or $PollingInterval -gt 3600) {
    $PollingInterval = 5
}

# --- 1) Settings & Logs ---
$LogDir = "$env:LOCALAPPDATA\YemekBildirimi"
if (-not (Test-Path $LogDir)) { New-Item -Path $LogDir -ItemType Directory -Force | Out-Null }
$LogFile = Join-Path $LogDir "client.log"

$ScriptDir = $PSScriptRoot
if (-not $ScriptDir) { $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }

$LogoPath = Join-Path $ScriptDir "assets\logo.png"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $Entry = "[$Timestamp] [$Level] $Message"
    Add-Content -Path $LogFile -Value $Entry -Encoding UTF8
    Write-Host $Entry
}

Write-Log "Starting Client. Server: $Server | Interval: ${PollingInterval}s"

# --- 2) Module Check ---
try {
    if (-not (Get-Module -Name BurntToast)) {
        Import-Module BurntToast -ErrorAction Stop
    }
}
catch {
    Write-Log "CRITICAL: BurntToast module could not be loaded. $_" "ERROR"
}

if (Test-Path $LogoPath) { Write-Log "Assets: Logo found at $LogoPath" }
else { Write-Log "Assets: Logo NOT found at $LogoPath" "WARNING" }

# --- 3) Single Instance Mutex ---
$MutexName = "Global\YemekBildirimiClient"
$Mutex = $null
$HasLock = $false

try {
    $createdNew = $false
    $Mutex = [System.Threading.Mutex]::new($false, $MutexName, [ref]$createdNew)
}
catch {
    Write-Log "Mutex Init Failed: $_" "ERROR"
    exit 1
}

try {
    if ($Mutex.WaitOne(0)) {
        $HasLock = $true
    }
    else {
        Write-Log "Instance already running. Exiting (0)." "INFO"
        exit 0
    }
}
catch {
    Write-Log "Mutex WaitOne Failed: $_" "ERROR"
    exit 1
}

# --- 4) HTTP Client (UTF-8) ---
$HttpClient = [System.Net.Http.HttpClient]::new()
$HttpClient.Timeout = [TimeSpan]::FromSeconds(10)

function Get-LatestNotification {
    try {
        $Url = "$Server/latest"
        $Bytes = $HttpClient.GetByteArrayAsync($Url).Result
        $JsonString = [System.Text.Encoding]::UTF8.GetString($Bytes)
        return ($JsonString | ConvertFrom-Json)
    }
    catch {
        Write-Log "HTTP Error (latest): $_" "ERROR"
        return $null
    }
}

# --- 5) Local State ---
$StateFile = Join-Path $LogDir "state.txt"
$LastId = 0
if (Test-Path $StateFile) {
    try {
        $LastId = [int](Get-Content $StateFile -ErrorAction Stop)
        Write-Log "State loaded. Last ID: $LastId"
    } catch {
        Write-Log "State file unreadable. Starting fresh." "WARNING"
        $LastId = 0
    }
} else {
    Write-Log "First run detected (no state file). Syncing with server..." "INFO"
}

try {
    Write-Log "Entering Polling Loop. Last ID: $LastId"

    while ($true) {
        $Data = Get-LatestNotification
        if ($null -ne $Data) {
            # Expecting fields like: id, text (based on your previous logs)
            $ServerId = 0
            $Text = $null

            try { $ServerId = [int]$Data.id } catch { $ServerId = 0 }
            try { $Text = [string]$Data.text } catch { $Text = "" }

            if ($ServerId -lt $LastId) {
                Write-Log "Server state reset detected. Local LastId=$LastId, ServerId=$ServerId. Resyncing without toast." "WARNING"
                $LastId = $ServerId
                $LastId | Out-File $StateFile -Encoding ascii -Force
            }
            elseif ($ServerId -gt $LastId) {
                # Show toast
                try {
                    if (Get-Command -Name New-BurntToastNotification -ErrorAction SilentlyContinue) {
                        New-BurntToastNotification -Text $Text -AppLogo $LogoPath -Silent:$false | Out-Null
                        Write-Log "Toast Displayed."
                    }
                    else {
                        Write-Log "BurntToast command not found!" "ERROR"
                    }
                }
                catch {
                    Write-Log "Toast Failed: $_" "ERROR"
                }

                $LastId = $ServerId
                $LastId | Out-File $StateFile -Encoding ascii -Force
            }
        }

        Start-Sleep -Seconds ([Math]::Max(1, [int]$PollingInterval))
    }
}
finally {
    if ($HttpClient) { $HttpClient.Dispose() }
    if ($Mutex -and $HasLock) {
        $Mutex.ReleaseMutex()
        $Mutex.Dispose()
    }
    Write-Log "Shutdown."
}
