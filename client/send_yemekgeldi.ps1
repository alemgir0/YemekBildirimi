param(
  [Parameter(Mandatory=$true)]
  [string]$Server,

  [Parameter(Mandatory=$true)]
  [string]$ApiKey,

  [string]$Message = "🍽️ Yemek geldi! Afiyet olsun."
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$Server = $Server.TrimEnd("/")
$Body = @{ text = $Message } | ConvertTo-Json -Compress

try {
  $resp = Invoke-RestMethod `
    -Uri "$Server/notify" `
    -Method Post `
    -Body $Body `
    -ContentType "application/json" `
    -Headers @{ "X-API-Key" = $ApiKey }

  if ($resp.ok) {
    Write-Host "SUCCESS: Notification sent! ID: $($resp.id)" -ForegroundColor Green
  } else {
    Write-Host "FAILED: Server returned ok=false" -ForegroundColor Red
  }
}
catch {
  $ex = $_.Exception
  if ($ex.Response -and $ex.Response.StatusCode) {
    try {
      $status = [int]$ex.Response.StatusCode
      $reader = New-Object System.IO.StreamReader($ex.Response.GetResponseStream())
      $bodyText = $reader.ReadToEnd()
      Write-Host "ERROR: HTTP $status - $bodyText" -ForegroundColor Red
    } catch {
      Write-Host "ERROR: $($_)" -ForegroundColor Red
    }
  } else {
    Write-Host "ERROR: $($_)" -ForegroundColor Red
  }
}
