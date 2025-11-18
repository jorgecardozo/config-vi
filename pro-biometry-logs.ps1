# Verificar parámetros
param(
    [string]$searchTerm,
    [string]$startDateParam,
    [string]$endDateParam
)

# Establece color por defecto
$Host.UI.RawUI.ForegroundColor = 'White'

# Función para procesar una fecha específica
function Process-SingleDate {
    param (
        [string]$searchTerm,
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

    Write-Host "Ejecutando consulta en $logGroup..." -ForegroundColor Cyan
    Write-Host "UUID: $searchTerm" -ForegroundColor Cyan
    Write-Host "Período: $startDate hasta $endDate" -ForegroundColor Cyan

    # Inicia la consulta
    $queryId = aws logs start-query `
        --log-group-name $logGroup `
        --start-time $startTime `
        --end-time $endTime `
        --query-string "fields @timestamp, @message, @logStream, @log | sort @timestamp desc | filter @log like '$searchTerm' or @logStream like '$searchTerm' or @message like '$searchTerm' | limit 10000" `
        --query 'queryId' `
        --output text

    Write-Host "Query ID: $queryId" -ForegroundColor Cyan
    Write-Host "Esperando resultados..." -ForegroundColor Cyan

    # Espera y obtiene resultados
    do {
        Start-Sleep -Seconds 1
        $results = aws logs get-query-results --query-id $queryId | ConvertFrom-Json
    } while ($results.status -eq "Running")

    # Contar resultados antes de mostrarlos
    $totalResults = if ($results.results) { $results.results.Count } else { 0 }
    Write-Host "`nResultados encontrados: " -NoNewline -ForegroundColor Yellow
    Write-Host "$totalResults" -ForegroundColor Cyan
    
    # Inicializar variables para detectar flujos
    $foundVivere = $false
    $foundAutogestivo = $false
    
    # Para debug y verificación
    $matchedVivereMessage = ""
    $matchedAutogestivoMessage = ""
    
    # Buscar referencias a los flujos en los resultados
    if ($results.results) {
        foreach ($result in $results.results) {
            foreach ($field in $result) {
                if ($field.field -eq "@message") {
                    # Buscar referencias a flujo vivere (múltiples patrones para mayor precisión)
                    if ($field.value -match "(?i)flujo\s+de\s+v[ií]vere" -or 
                        $field.value -match "(?i)flujo\s+v[ií]vere") {
                        $foundVivere = $true
                        $matchedVivereMessage = $field.value
                    }
                    
                    # Buscar referencias a flujo autogestivo (múltiples patrones para mayor precisión)
                    if ($field.value -match "(?i)flujo\s+de\s+autogestivo" -or 
                        $field.value -match "(?i)flujo\s+autogestivo") {
                        $foundAutogestivo = $true
                        $matchedAutogestivoMessage = $field.value
                    }
                }
            }
        }
    }
    
    # Mostrar resultados de detección de flujos
    Write-Host "Flujo vivere: " -NoNewline -ForegroundColor Yellow
    if ($foundVivere) {
        Write-Host "OK" -ForegroundColor Green
        Write-Host "  Mensaje encontrado: " -NoNewline -ForegroundColor Gray
        Write-Host "$matchedVivereMessage" -ForegroundColor Gray
    } else {
        Write-Host "NOK" -ForegroundColor Red
    }
    
    Write-Host "Flujo autogestivo: " -NoNewline -ForegroundColor Yellow
    if ($foundAutogestivo) {
        Write-Host "OK" -ForegroundColor Green
        Write-Host "  Mensaje encontrado: " -NoNewline -ForegroundColor Gray
        Write-Host "$matchedAutogestivoMessage" -ForegroundColor Gray
    } else {
        Write-Host "NOK" -ForegroundColor Red
    }
    
    Write-Host ("-" * 80)
    Write-Host ""

    # Mostrar resultados
    if ($results.results) {
        # Contar la cantidad total de logs
        $totalLogs = $results.results.Count
        
        # Recorrer los resultados en orden inverso
        for ($i = $totalLogs - 1; $i -ge 0; $i--) {
            $result = $results.results[$i]
            
            # Usa el número invertido para mostrar (totalLogs - i)
            $logNumber = $totalLogs - $i
            
            # Convierte el resultado en un hashtable para fácil acceso
            $logEntry = @{}
            foreach ($field in $result) {
                $logEntry[$field.field] = $field.value
            }

            # Formatea la hora (restar 3 horas)
            $timestamp = [DateTime]::Parse($logEntry['@timestamp'])
            $timestamp = $timestamp.AddHours(-3)
            $formattedTime = $timestamp.ToString("yyyy-MM-ddTHH:mm:ss.fffZ")

            # Procesa y formatea el mensaje
            $formattedMessage = Format-JsonMessage $logEntry['@message']

            # Imprime el log formateado con colores
            Write-Host "Log número " -NoNewline -ForegroundColor Yellow
            Write-Host "$logNumber" -ForegroundColor White
            
            # Divide el mensaje formateado en líneas
            $messageLines = $formattedMessage -split "`n"
            foreach ($line in $messageLines) {
                if ($line.StartsWith("Datos: ")) {
                    Write-Host "Datos: " -NoNewline -ForegroundColor Yellow
                    Write-Host ($line.Substring(6)) -ForegroundColor Green
                }
                elseif ($line.StartsWith("User Agent:")) {
                    Write-Host "User Agent: " -NoNewline -ForegroundColor Yellow
                    Write-Host "" -ForegroundColor Green
                }
                elseif ($line.StartsWith("  [")) {
                    Write-Host $line -ForegroundColor Green
                }
                else {
                    Write-Host "Mensaje: " -NoNewline -ForegroundColor Yellow
                    if ($line.TrimStart().StartsWith("[ERROR]:")) {
                        Write-Host $line -ForegroundColor Red
                    } else {
                        Write-Host $line -ForegroundColor Green
                    }
                }
            }
            
            Write-Host "Hora: " -NoNewline -ForegroundColor Yellow
            Write-Host "$formattedTime" -ForegroundColor Green
            Write-Host ("-" * 80) -ForegroundColor White
            Write-Host ""

            # No incrementamos logNumber porque ya lo estamos calculando en el bucle
        }
    } else {
        Write-Host "No se encontraron resultados para esta fecha" -ForegroundColor Red
        Write-Host ("-" * 80)
    }
}

# Función para formatear mensajes JSON
function Format-JsonMessage {
    param (
        [string]$message
    )

    # Para mensajes con Data simple
    if ($message -match '\| Data: ({.+?})(?:\s|$)') {
        try {
            $jsonPart = $matches[1]
            $jsonData = $jsonPart | ConvertFrom-Json
            $messageBase = $message.Substring(0, $message.IndexOf('| Data:'))
            $properties = @()
            $jsonData.PSObject.Properties | ForEach-Object {
                $properties += "$($.Name): $($.Value)"
            }
            return "$messageBase`nDatos: $($properties -join ' | ')"
        }
        catch {
            return $message
        }
    }
    # Para mensajes con User Agent
    elseif ($message -match '\| User Agent: ({.+})$') {
        try {
            $messageBase = $message.Substring(0, $message.IndexOf('| User Agent:'))
            $jsonString = $message.Substring($message.IndexOf('| User Agent: ') + 13)
            $jsonData = $jsonString | ConvertFrom-Json -AsHashtable

            $output = New-Object System.Collections.ArrayList
            $output.Add($messageBase) | Out-Null
            $output.Add("User Agent:") | Out-Null

            foreach ($key in $jsonData.Keys | Sort-Object) {
                $value = $jsonData[$key]
                if ($value -is [Hashtable] -and $value.Count -gt 0) {
                    $subProps = @()
                    foreach ($subKey in $value.Keys | Sort-Object) {
                        # Solo incluir name y version para browser
                        if ($key -eq "browser" -and ($subKey -eq "name" -or $subKey -eq "version")) {
                            $subProps += "${subKey}: $($value[$subKey])"
                        }
                        # Para otros objetos, incluir todas las propiedades
                        elseif ($key -ne "browser") {
                            $subProps += "${subKey}: $($value[$subKey])"
                        }
                    }
                    if ($subProps.Count -gt 0) {
                        $output.Add("  [$key] - $($subProps -join ' | ')") | Out-Null
                    }
                }
                elseif ($value -is [Hashtable] -and $value.Count -eq 0) {
                    $output.Add("  [$key]: {}") | Out-Null
                }
                else {
                    $output.Add("  [$key]: $value") | Out-Null
                }
            }

            return $output -join "`n"
        }
        catch {
            Write-Host "Error procesando JSON: $_" -ForegroundColor Red
            return $message
        }
    }
    return $message
}

# Valida parámetros
if (-not $searchTerm) {
    Write-Host "Error: Debe ingresar el UUID de la biometría como primer parámetro" -ForegroundColor Red
    Write-Host "Ejemplo de uso: ./script.ps1 'b08b88b9-c8cf-4506-bdbc-22a1169c23a2' '15/11/2024' '20/11/2024'" -ForegroundColor Yellow
    Write-Host "Parámetro 1: UUID de la biometría" -ForegroundColor Cyan
    Write-Host "Parámetro 2: Fecha inicial en formato DD/MM/YYYY" -ForegroundColor Cyan
    Write-Host "Parámetro 3: Fecha final en formato DD/MM/YYYY" -ForegroundColor Cyan
    exit
}

if (-not $startDateParam -or -not $endDateParam) {
    Write-Host "Error: Debe ingresar la fecha inicial y final como segundo y tercer parámetro" -ForegroundColor Red
    Write-Host "Ejemplo de uso: ./script.ps1 'b08b88b9-c8cf-4506-bdbc-22a1169c23a2' '15/11/2024' '20/11/2024'" -ForegroundColor Yellow
    Write-Host "Parámetro 1: UUID de la biometría" -ForegroundColor Cyan
    Write-Host "Parámetro 2: Fecha inicial en formato DD/MM/YYYY" -ForegroundColor Cyan
    Write-Host "Parámetro 3: Fecha final en formato DD/MM/YYYY" -ForegroundColor Cyan
    exit
}

# Configura el perfil de AWS
$env:AWS_PROFILE = "prendarios-dev"

# LogGroup
$logGroup = "/sc/prendarios/autogestivo-front-prod/biometria"

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
Write-Host "UUID de biometría: $searchTerm" -ForegroundColor Green

# Procesar cada fecha en el rango
$currentDate = $startDate
while ($currentDate -le $endDate) {
    Process-SingleDate -searchTerm $searchTerm -fecha $currentDate
    $currentDate = $currentDate.AddDays(1)
}

# Resumen final de todos los días
Write-Host "`n====================================" -ForegroundColor Cyan
Write-Host "RESUMEN GENERAL DEL RANGO COMPLETO" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan
Write-Host "UUID de biometría: $searchTerm" -ForegroundColor Cyan
Write-Host "Período: $($startDate.ToString('dd/MM/yyyy')) hasta $($endDate.ToString('dd/MM/yyyy'))" -ForegroundColor Cyan
Write-Host "`nProcesamiento completado para todas las fechas en el rango." -ForegroundColor Green

# Restaura el color original
$Host.UI.RawUI.ForegroundColor = 'White'