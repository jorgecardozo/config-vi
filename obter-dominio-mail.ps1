param (
    [string]$AliasList
)

if (-not $AliasList) {
    Write-Host "Favor pasar los alias usando -AliasList" -ForegroundColor Yellow
    exit
}

$aliases = $AliasList -split ','

foreach ($alias in $aliases) {
    $alias = $alias.Trim()
    Write-Host "Buscando: $alias" -ForegroundColor Cyan
    
    $recipients = Get-Recipient -Filter "EmailAddresses -like '*$alias*'"
    
    if ($recipients) {
        foreach ($recipient in $recipients) {
            $email = $recipient.PrimarySmtpAddress.ToString()
            $domain = $email.Split("@")[1]
            Write-Host "Encontrado: $($recipient.DisplayName) -> $email -> Dominio: $domain" -ForegroundColor Green
        }
    } else {
        Write-Host "No encontrado: $alias" -ForegroundColor Red
    }
    Write-Host ""
}