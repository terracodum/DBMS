# =====================================================================
# РГР. Вариант 11 - "Автостоянка"
# Автоматический прогон всех SQL-скриптов с сохранением протокола
#
# Запуск из PowerShell:
#     cd X:\Coding\work\DBMS\archive\sql\parking
#     .\run_all.ps1
# Если пароль суперпользователя postgres отличается от "postgres":
#     .\run_all.ps1 -Password "ваш_пароль"
# =====================================================================
param(
    [string]$Password = "postgres",
    [string]$User     = "postgres",
    [string]$PgHost   = "127.0.0.1",
    [int]   $Port     = 5432
)

chcp 65001 > $null
$OutputEncoding = [System.Text.Encoding]::UTF8
$env:PGCLIENTENCODING = "UTF8"
$env:PGPASSWORD = $Password

# --- поиск psql.exe ---------------------------------------------------
$psql = (Get-Command psql -ErrorAction SilentlyContinue).Source
if (-not $psql) {
    $found = Get-ChildItem 'C:\Program Files\PostgreSQL\*\bin\psql.exe' -ErrorAction SilentlyContinue |
             Sort-Object FullName -Descending | Select-Object -First 1
    if ($found) { $psql = $found.FullName }
}
if (-not $psql) {
    Write-Host "psql.exe не найден. Установите PostgreSQL или добавьте его каталог bin в PATH." -ForegroundColor Red
    exit 1
}
Write-Host "Используется: $psql" -ForegroundColor Cyan

$logDir = Join-Path $PSScriptRoot "../../logs"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

function Invoke-Sql {
    param([string]$Db, [string]$File, [switch]$AllowErrors)

    $name = [System.IO.Path]::GetFileNameWithoutExtension($File)
    $log  = Join-Path $logDir "$name.log"
    Write-Host ""
    Write-Host ">>> $name  (база: $Db)" -ForegroundColor Yellow

    $args = @('-h', $PgHost, '-p', $Port, '-U', $User, '-d', $Db,
              '-f', (Join-Path $PSScriptRoot $File), '-a', '-e')
    if (-not $AllowErrors) { $args += @('-v', 'ON_ERROR_STOP=1') }

    $out = (& $psql @args 2>&1 | Out-String)
    Write-Host $out
    [System.IO.File]::WriteAllText($log, $out, (New-Object System.Text.UTF8Encoding $false))
    if ($LASTEXITCODE -ne 0 -and -not $AllowErrors) {
        Write-Host "ОШИБКА при выполнении $File. Протокол: $log" -ForegroundColor Red
        exit 1
    }
    Write-Host "готово, протокол: $log" -ForegroundColor Green
}

# --- основные файлы работы ---
Invoke-Sql -Db 'postgres' -File 'lab2_parking_db.sql'
Invoke-Sql -Db 'parking'  -File 'lab3_parking_tables.sql'

Invoke-Sql -Db 'parking'  -File 'lab3_parking_data.sql'
Invoke-Sql -Db 'parking'  -File 'lab4_parking_array_json.sql'
Invoke-Sql -Db 'parking'  -File 'lab4_textbook_example.sql'
Invoke-Sql -Db 'parking'  -File 'lab5_parking_queries.sql'

# --- вспомогательные файлы для раздела «Результаты» отчёта ---

# integrity_tests.sql содержит заведомо ошибочные инструкции - это
# проверка работы ограничений, поэтому ON_ERROR_STOP отключён
Invoke-Sql -Db 'parking'  -File 'test\integrity_tests.sql' -AllowErrors

Invoke-Sql -Db 'parking'  -File 'test\structure_report.sql'

Write-Host ""
Write-Host "Все скрипты выполнены. Протоколы для отчёта: $logDir" -ForegroundColor Cyan
$env:PGPASSWORD = ""
