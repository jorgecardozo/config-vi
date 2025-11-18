# Verificar parámetros
param(
    [string]$proposalNumber,
    [string]$searchDate
)

# Establece el color por defecto
$Host.UI.RawUI.ForegroundColor = 'White'

# Función para traducir los estados
function Get-StatusDescription {
    param (
        [string]$statusF
    )
    
    switch ($status) {
        'P'  { 'PENDIENTE' }
        'FC' { 'FINALIZADO CORRECTAMENTE' }
        'FE' { 'FINALIZADO CON ERRORES' }
        'I'  { 'INICIADO' }
        'FF' { 'POSIBLE FRAUDE' }
        default { 'ESTADO DESCONOCIDO' }
    }
}

# Valida parámetros
if (-not $proposalNumber) {
    Write-Host "Error: Debe ingresar el número de propuesta o DNI" -ForegroundColor Red
    Write-Host "Ejemplo de uso: ./script.ps1 '732509' '15/11/2024'" -ForegroundColor Yellow
    Write-Host "Parámetro 1: Número de propuesta" -ForegroundColor Cyan
    Write-Host "Parámetro 2: Fecha en formato DD/MM/YYYY" -ForegroundColor Cyan
    exit
}

if (-not $searchDate) {
    Write-Host "Error: Debe ingresar la fecha como segundo parámetro" -ForegroundColor Red
    Write-Host "Ejemplo de uso: ./script.ps1 '732509' '15/11/2024'" -ForegroundColor Yellow
    Write-Host "Parámetro 1: Número de propuesta" -ForegroundColor Cyan
    Write-Host "Parámetro 2: Fecha en formato DD/MM/YYYY" -ForegroundColor Cyan
    exit
}

# Configura el perfil de AWS
$env:AWS_PROFILE = "shared-services"

# LogGroup
$logGroup = "/aws/lambda/biometricPrendariosgenerateId_prod"

# Convierte fecha de DD/MM/YYYY a formato ISO
try {
    $fecha = [DateTime]::ParseExact($searchDate, "dd/MM/yyyy", $null)
    $startDate = $fecha.ToString("yyyy-MM-ddT00:00:00")
    $endDate = $fecha.ToString("yyyy-MM-ddT23:59:59")
}
catch {
    Write-Host "Error: El formato de fecha debe ser DD/MM/YYYY" -ForegroundColor Red
    Write-Host "Ejemplo: 15/11/2024" -ForegroundColor Yellow
    exit
}

# Convierte fechas a timestamp Unix
$startTime = [Math]::Floor([decimal](([DateTime]::Parse($startDate)).ToUniversalTime().Subtract((Get-Date "1970-01-01")).TotalSeconds))
$endTime = [Math]::Floor([decimal](([DateTime]::Parse($endDate)).ToUniversalTime().Subtract((Get-Date "1970-01-01")).TotalSeconds))

Write-Host "Ejecutando consulta para obtener requestId..." -ForegroundColor Cyan
Write-Host "Proposal Number: $proposalNumber" -ForegroundColor Cyan
Write-Host "Fecha: $startDate hasta $endDate" -ForegroundColor Cyan

# Primera consulta - Obtener requestId
$queryId = aws logs start-query `
    --log-group-name $logGroup `
    --start-time $startTime `
    --end-time $endTime `
    --query-string "fields @timestamp, @message, @logStream, @log, @requestId | filter @message like '$proposalNumber' | sort @timestamp desc | limit 10000" `
    --query 'queryId' `
    --output text

if (-not $queryId) {
    Write-Host "Error al ejecutar la consulta" -ForegroundColor Red
    exit
}

Write-Host "Query ID: $queryId" -ForegroundColor Cyan
Write-Host "Esperando resultados..." -ForegroundColor Cyan

# Espera resultados de la primera consulta
do {
    Start-Sleep -Seconds 1
    $results = aws logs get-query-results --query-id $queryId | ConvertFrom-Json
} while ($results.status -eq "Running")

Write-Host "`nResultados de la primera consulta:" -ForegroundColor Cyan
# $results.results | ForEach-Object {
#     Write-Host ($_ | ConvertTo-Json)
# }

$requestId = $null
foreach ($result in $results.results) {
    foreach ($field in $result) {
        if ($field.field -eq "@requestId" -and -not $requestId) {
            $requestId = $field.value
        }
    }
}

# Verifica si se encontró requestId
if ($requestId) {
    Write-Host "`nRequest ID encontrado: " -NoNewline -ForegroundColor Yellow
    Write-Host "$requestId" -ForegroundColor Green

    # Segunda consulta - Obtener UUID
    Write-Host "`nBuscando UUID asociado con RequestID: $requestId..." -ForegroundColor Cyan
    $queryId = aws logs start-query `
        --log-group-name $logGroup `
        --start-time $startTime `
        --end-time $endTime `
        --query-string "fields @timestamp, @message, @logStream, @log | filter @message like '$requestId' | filter @message like 'The uuid inserted' | sort @timestamp desc | limit 10000" `
        --query 'queryId' `
        --output text

    if (-not $queryId) {
        Write-Host "Error al ejecutar la segunda consulta" -ForegroundColor Red
        exit
    }

    Write-Host "Esperando resultados..." -ForegroundColor Cyan

    # Espera resultados de la segunda consulta
    do {
        Start-Sleep -Seconds 1
        $results = aws logs get-query-results --query-id $queryId | ConvertFrom-Json
    } while ($results.status -eq "Running")

    Write-Host "`nResultados de la segunda consulta:" -ForegroundColor Cyan
    # $results.results | ForEach-Object {
    #     Write-Host ($_ | ConvertTo-Json)
    # }

    # Extrae UUID del mensaje
    if ($results.results -and $results.results.Count -gt 0) {
        $message = ($results.results | 
            Where-Object { $_.field -eq "@message" } | 
            Select-Object -First 1).value

        $message = $message.Trim()
        #Write-Host "`nMensaje encontrado para UUID: $message" -ForegroundColor Yellow

        $match = $message | Select-String -Pattern "The uuid inserted:\s+(.*)"
        Write-Host "Resultado match UUID: $($match.Matches.Groups[1].Value)" -ForegroundColor Yellow

        if ($match) { 
            $uuid = $match.Matches.Groups[1].Value

            # Tercera consulta - Buscar estado
            Write-Host "`nBuscando estado para RequestID: $requestId..." -ForegroundColor Cyan
            $queryId = aws logs start-query `
                --log-group-name $logGroup `
                --start-time $startTime `
                --end-time $endTime `
                --query-string "fields @timestamp, @message, @logStream, @log | filter @message like '$requestId' | filter @message like 'INSERT INTO' | sort @timestamp desc | limit 10000" `
                --query 'queryId' `
                --output text

            if (-not $queryId) {
                Write-Host "Error al ejecutar la tercera consulta" -ForegroundColor Red
                exit
            }

            Write-Host "Esperando resultados..." -ForegroundColor Cyan

            # Espera resultados de la tercera consulta
            do {
                Start-Sleep -Seconds 1
                $results = aws logs get-query-results --query-id $queryId | ConvertFrom-Json
            } while ($results.status -eq "Running")

            Write-Host "`nResultados de la tercera consulta:" -ForegroundColor Cyan
            # $results.results | ForEach-Object {
            #     Write-Host ($_ | ConvertTo-Json)
            # }

            $status = "NO ENCONTRADO"
            if ($results.results -and $results.results.Count -gt 0) {
                $insertMessage = ($results.results | 
                    Where-Object { $_.field -eq "@message" } | 
                    Select-Object -First 1).value

                # Write-Host "`nMensaje INSERT encontrado: $insertMessage" -ForegroundColor Yellow
                
                # Intentar match con cada estado posible
                Write-Host "Buscando coincidencias de estado..." -ForegroundColor Cyan
                
                $matchP = $insertMessage | Select-String -Pattern "'P'"
                # Write-Host "Match P: $($matchP -ne $null)" -ForegroundColor Yellow
                
                $matchFC = $insertMessage | Select-String -Pattern "'FC'"
                # Write-Host "Match FC: $($matchFC -ne $null)" -ForegroundColor Yellow
                
                $matchFE = $insertMessage | Select-String -Pattern "'FE'"
                # Write-Host "Match FE: $($matchFE -ne $null)" -ForegroundColor Yellow
                
                $matchI = $insertMessage | Select-String -Pattern "'I'"
                # Write-Host "Match I: $($matchI -ne $null)" -ForegroundColor Yellow
                
                $matchFF = $insertMessage | Select-String -Pattern "'FF'"
                # Write-Host "Match FF: $($matchFF -ne $null)" -ForegroundColor Yellow

                if ($matchP) { $status = "P" }
                elseif ($matchFC) { $status = "FC" }
                elseif ($matchFE) { $status = "FE" }
                elseif ($matchI) { $status = "I" }
                elseif ($matchFF) { $status = "FF" }
                
                Write-Host "Estado encontrado: $status" -ForegroundColor Yellow
            }

            $statusDescription = Get-StatusDescription $status
            Write-Host "`nResultado:" -ForegroundColor Yellow
            Write-Host "Numero de propuesta o DNI: " -NoNewline -ForegroundColor Yellow
            Write-Host "$proposalNumber" -ForegroundColor Green
            Write-Host "UUID: " -NoNewline -ForegroundColor Yellow
            Write-Host "$uuid" -ForegroundColor Green
            Write-Host "Estado: " -NoNewline -ForegroundColor Yellow
            Write-Host "$statusDescription" -ForegroundColor Green

        } else {
            Write-Host "No se pudo extraer el UUID del mensaje" -ForegroundColor Red
        }
    } else {
        Write-Host "No se encontró el UUID asociado" -ForegroundColor Red
    }
} else {
    Write-Host "No se encontró el requestId en los resultados" -ForegroundColor Red
}

# Restaurar color original
$Host.UI.RawUI.ForegroundColor = 'White'