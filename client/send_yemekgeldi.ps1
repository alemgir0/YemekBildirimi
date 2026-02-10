param (
    [string]$Server = "http://192.168.2.210:8787",
    [string]$ApiKey,
    [string]$Message = "🍽️ Yemek geldi! Afiyet olsun."
)

$Body = @{ text = $Message } | ConvertTo-Json -Compress

try {
    $Response = Invoke-RestMethod -Uri "$Server/notify" -Method Post -Body $Body -ContentType "application/json" -Headers @{ "X-API-Key" = $ApiKey }
    if ($Response.ok) {
        Write-Host "SUCCESS: Notification sent! ID: $($Response.id)" -ForegroundColor Green
    }
    else {
        Write-Host "FAILED: Server returned error." -ForegroundColor Red
    }
}
catch {
    Write-Host "ERROR: $_" -ForegroundColor Red
}
