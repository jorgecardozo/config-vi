# Verificar parámetros
param(
    [string]$proposalNumber,
    [string]$startDateParam,
    [string]$endDateParam
)

# Establece el color por defecto
$Host.UI.RawUI.ForegroundColor = 'White'

# Función para traducir los estados
function Get-StatusDescription {
    param (
        [string]$status
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

# Función para procesar una fecha específica
function Process-SingleDate {
    param (
        [string]$proposalNumber,
        [DateTime]$fecha
    )
    
    $dateFormatted = $fecha.ToString("dd/MM/yyyy")
    Write-Host "`n====================================" -ForegroundColor Cyan
    Write-Host "Fecha: $dateFormatted" -ForegroundColor Cyan
    Write-Host "====================================" -ForegroundColor Cyan
    
    $startDate = $fecha.ToString("yyyy-MM-ddT00:00:00")
    $endDate = $fecha.ToString("yyyy-MM-ddT23:59:59")
    
    # Convierte fechas a timestamp Unix
    $startTime = [Math]::Floor([decimal](([DateTime]::Parse($startDate)).ToUniversalTime().Subtract((Get-Date "1970-01-01")).TotalSeconds))
    $endTime = [Math]::Floor([decimal](([DateTime]::Parse($endDate)).ToUniversalTime().Subtract((Get-Date "1970-01-01")).TotalSeconds))

    #Write-Host "Ejecutando consulta para obtener requestId..." -ForegroundColor Cyan
    Write-Host "Proposal Number: $proposalNumber" -ForegroundColor Cyan
    Write-Host "Fecha: $startDate hasta $endDate" -ForegroundColor Cyan
    Write-Host "Esperando resultados..." -ForegroundColor Cyan

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
        return
    }

    #Write-Host "Query ID: $queryId" -ForegroundColor Cyan
    #Write-Host "Esperando resultados..." -ForegroundColor Cyan

    # Espera resultados de la primera consulta
    do {
        Start-Sleep -Seconds 1
        $results = aws logs get-query-results --query-id $queryId | ConvertFrom-Json
    } while ($results.status -eq "Running")

    #Write-Host "`nResultados de la primera consulta:" -ForegroundColor Cyan

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
        #Write-Host "`nRequest ID encontrado: " -NoNewline -ForegroundColor Yellow
        #Write-Host "$requestId" -ForegroundColor Green

        # Segunda consulta - Obtener UUID
        #Write-Host "`nBuscando UUID asociado con RequestID: $requestId..." -ForegroundColor Cyan
        $queryId = aws logs start-query `
            --log-group-name $logGroup `
            --start-time $startTime `
            --end-time $endTime `
            --query-string "fields @timestamp, @message, @logStream, @log | filter @message like '$requestId' | filter @message like 'The uuid inserted' | sort @timestamp desc | limit 10000" `
            --query 'queryId' `
            --output text

        if (-not $queryId) {
            Write-Host "Error al ejecutar la segunda consulta" -ForegroundColor Red
            return
        }

        #Write-Host "Esperando resultados..." -ForegroundColor Cyan

        # Espera resultados de la segunda consulta
        do {
            Start-Sleep -Seconds 1
            $results = aws logs get-query-results --query-id $queryId | ConvertFrom-Json
        } while ($results.status -eq "Running")

        #Write-Host "`nResultados de la segunda consulta:" -ForegroundColor Cyan

        # Extrae UUID del mensaje
        if ($results.results -and $results.results.Count -gt 0) {
            $message = ($results.results | 
                Where-Object { $_.field -eq "@message" } | 
                Select-Object -First 1).value

            $message = $message.Trim()

            $match = $message | Select-String -Pattern "The uuid inserted:\s+(.*)"
            #Write-Host "Resultado match UUID: $($match.Matches.Groups[1].Value)" -ForegroundColor Yellow

            if ($match) { 
                $uuid = $match.Matches.Groups[1].Value

                # Tercera consulta - Buscar estado
                #Write-Host "`nBuscando estado para RequestID: $requestId..." -ForegroundColor Cyan
                $queryId = aws logs start-query `
                    --log-group-name $logGroup `
                    --start-time $startTime `
                    --end-time $endTime `
                    --query-string "fields @timestamp, @message, @logStream, @log | filter @message like '$requestId' | filter @message like 'INSERT INTO' | sort @timestamp desc | limit 10000" `
                    --query 'queryId' `
                    --output text

                if (-not $queryId) {
                    Write-Host "Error al ejecutar la tercera consulta" -ForegroundColor Red
                    return
                }

                #Write-Host "Esperando resultados..." -ForegroundColor Cyan

                # Espera resultados de la tercera consulta
                do {
                    Start-Sleep -Seconds 1
                    $results = aws logs get-query-results --query-id $queryId | ConvertFrom-Json
                } while ($results.status -eq "Running")

                #Write-Host "`nResultados de la tercera consulta:" -ForegroundColor Cyan

                $status = "NO ENCONTRADO"
                # if ($results.results -and $results.results.Count -gt 0) {
                #     $insertMessage = ($results.results | 
                #         Where-Object { $_.field -eq "@message" } | 
                #         Select-Object -First 1).value
                    
                #     # Intentar match con cada estado posible
                #     #Write-Host "Buscando coincidencias de estado..." -ForegroundColor Cyan
                    
                #     $matchP = $insertMessage | Select-String -Pattern "'P'"
                #     $matchFC = $insertMessage | Select-String -Pattern "'FC'"
                #     $matchFE = $insertMessage | Select-String -Pattern "'FE'"
                #     $matchI = $insertMessage | Select-String -Pattern "'I'"
                #     $matchFF = $insertMessage | Select-String -Pattern "'FF'"

                #     if ($matchP) { $status = "P" }
                #     elseif ($matchFC) { $status = "FC" }
                #     elseif ($matchFE) { $status = "FE" }
                #     elseif ($matchI) { $status = "I" }
                #     elseif ($matchFF) { $status = "FF" }
                    
                #     #Write-Host "Estado encontrado: $status" -ForegroundColor Yellow
                # }

                $statusDescription = Get-StatusDescription $status
                Write-Host "`nResultado:" -ForegroundColor Yellow
                Write-Host "Fecha: " -NoNewline -ForegroundColor Yellow
                Write-Host "$dateFormatted" -ForegroundColor Green
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
}

# Valida parámetros
if (-not $proposalNumber) {
    Write-Host "Error: Debe ingresar el número de propuesta o DNI" -ForegroundColor Red
    Write-Host "Ejemplo de uso: ./script.ps1 '732509' '15/11/2024' '20/11/2024'" -ForegroundColor Yellow
    Write-Host "Parámetro 1: Número de propuesta" -ForegroundColor Cyan
    Write-Host "Parámetro 2: Fecha inicial en formato DD/MM/YYYY" -ForegroundColor Cyan
    Write-Host "Parámetro 3: Fecha final en formato DD/MM/YYYY" -ForegroundColor Cyan
    exit
}

if (-not $startDateParam -or -not $endDateParam) {
    Write-Host "Error: Debe ingresar la fecha inicial y final como segundo y tercer parámetro" -ForegroundColor Red
    Write-Host "Ejemplo de uso: ./script.ps1 '732509' '15/11/2024' '20/11/2024'" -ForegroundColor Yellow
    Write-Host "Parámetro 1: Número de propuesta" -ForegroundColor Cyan
    Write-Host "Parámetro 2: Fecha inicial en formato DD/MM/YYYY" -ForegroundColor Cyan
    Write-Host "Parámetro 3: Fecha final en formato DD/MM/YYYY" -ForegroundColor Cyan
    exit
}

# Configura el perfil de AWS
$env:AWS_PROFILE = "shared-services"

# LogGroup
$logGroup = "/aws/lambda/biometricPrendariosgenerateId_prod"

# Convierte fechas de DD/MM/YYYY a DateTime
try {
    $startDate = [DateTime]::ParseExact($startDateParam, "dd/MM/yyyy", $null)
    $endDate = [DateTime]::ParseExact($endDateParam, "dd/MM/yyyy", $null)
    
    # Valida que la fecha final no sea anterior a la inicial
    if ($endDate -lt $startDate) {
        Write-Host "Error: La fecha final no puede ser anterior a la fecha inicial" -ForegroundColor Red
        exit
    }
}
catch {
    Write-Host "Error: El formato de fecha debe ser DD/MM/YYYY" -ForegroundColor Red
    Write-Host "Ejemplo: 15/11/2024" -ForegroundColor Yellow
    exit
}

# Mostrar rango de fechas a procesar
Write-Host "`nProcesando consultas para el rango de fechas:" -ForegroundColor Yellow
Write-Host "Desde: $($startDate.ToString('dd/MM/yyyy'))" -ForegroundColor Green
Write-Host "Hasta: $($endDate.ToString('dd/MM/yyyy'))" -ForegroundColor Green
Write-Host "Propuesta/DNI: $proposalNumber" -ForegroundColor Green

# Procesar cada fecha en el rango
$currentDate = $startDate
while ($currentDate -le $endDate) {
    Process-SingleDate -proposalNumber $proposalNumber -fecha $currentDate
    $currentDate = $currentDate.AddDays(1)
}

Write-Host "`nProcesamiento completado para todas las fechas en el rango." -ForegroundColor Green

# Restaurar color original
$Host.UI.RawUI.ForegroundColor = 'White'