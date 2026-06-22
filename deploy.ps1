#Requires -RunAsAdministrator

$ErrorActionPreference = "Stop"

$DB_ADMIN_PASS = $env:DB_ADMIN_PASS
$DB_APP_PASS   = $env:DB_APP_PASS

if ([string]::IsNullOrEmpty($DB_ADMIN_PASS)) {
    Write-Error "[ОШИБКА] Переменная DB_ADMIN_PASS не задана. Введи: `$env:DB_ADMIN_PASS = 'пароль'"
    exit 1
}
if ([string]::IsNullOrEmpty($DB_APP_PASS)) {
    Write-Error "[ОШИБКА] Переменная DB_APP_PASS не задана. Введи: `$env:DB_APP_PASS = 'пароль'"
    exit 1
}

Write-Host "[1/6] Пароли считаны успешно." -ForegroundColor Green

$INSTALLER = "C:\logitrack\postgresql-17.10-1-windows-x64.exe"
$PG_VERSION = "17"
$PG_INSTALL_DIR = "C:\Program Files\PostgreSQL\$PG_VERSION"
$SERVICE_NAME = "postgresql-x64-$PG_VERSION"

if (-not (Test-Path $INSTALLER)) {
    Write-Error "[ОШИБКА] Файл не найден: $INSTALLER`nПоложи инсталлятор в папку C:\logitrack\"
    exit 1
}

Write-Host "[2/6] Запуск тихой установки PostgreSQL $PG_VERSION..." -ForegroundColor Cyan
Write-Host "      (это займёт 1-2 минуты, подожди...)" -ForegroundColor Yellow

Start-Process -FilePath $INSTALLER -Wait -ArgumentList @(
    "--mode",             "unattended",
    "--unattendedmodeui", "none",
    "--superpassword",    $DB_ADMIN_PASS,
    "--servicename",      $SERVICE_NAME,
    "--datadir",          "C:\PostgreSQL\$PG_VERSION\data",
    "--install_runtimes", "0"
)

Write-Host "[2/6] Установка завершена." -ForegroundColor Green

Write-Host "[3/6] Проверка сервиса PostgreSQL..." -ForegroundColor Cyan
Start-Sleep -Seconds 5

$svc = Get-Service -Name $SERVICE_NAME -ErrorAction SilentlyContinue
if ($null -eq $svc) {
    Write-Error "[ОШИБКА] Сервис $SERVICE_NAME не найден. Установка могла пройти с ошибкой."
    exit 1
}
if ($svc.Status -ne "Running") {
    Start-Service -Name $SERVICE_NAME
    Start-Sleep -Seconds 3
}
Write-Host "[3/6] Сервис PostgreSQL запущен." -ForegroundColor Green

$PSQL = "$PG_INSTALL_DIR\bin\psql.exe"
$env:PGPASSWORD = $DB_ADMIN_PASS

Write-Host "[4/6] Создание ролей и базы данных..." -ForegroundColor Cyan

# Создание роли logi_admin
$check = & $PSQL -U postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='logi_admin'" 2>$null
if ($check -ne "1") {
    & $PSQL -U postgres -c "CREATE ROLE logi_admin WITH LOGIN PASSWORD '$DB_ADMIN_PASS';"
    Write-Host "      Роль logi_admin создана." -ForegroundColor Green
} else {
    Write-Host "      Роль logi_admin уже существует." -ForegroundColor Yellow
}

# Создание роли logi_app
$check = & $PSQL -U postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='logi_app'" 2>$null
if ($check -ne "1") {
    & $PSQL -U postgres -c "CREATE ROLE logi_app WITH LOGIN PASSWORD '$DB_APP_PASS';"
    Write-Host "      Роль logi_app создана." -ForegroundColor Green
} else {
    Write-Host "      Роль logi_app уже существует." -ForegroundColor Yellow
}

# Создание базы данных
$check = & $PSQL -U postgres -tAc "SELECT 1 FROM pg_database WHERE datname='logitrack_db'" 2>$null
if ($check -ne "1") {
    & $PSQL -U postgres -c "CREATE DATABASE logitrack_db OWNER logi_admin ENCODING 'UTF8';"
    Write-Host "      База данных logitrack_db создана." -ForegroundColor Green
} else {
    Write-Host "      База данных logitrack_db уже существует." -ForegroundColor Yellow
}

Write-Host "[4/6] Роли и БД готовы." -ForegroundColor Green

Write-Host "[5/6] Настройка прав доступа..." -ForegroundColor Cyan

& $PSQL -U postgres -d logitrack_db -c "GRANT CONNECT ON DATABASE logitrack_db TO logi_app;" | Out-Null
& $PSQL -U postgres -d logitrack_db -c "GRANT USAGE ON SCHEMA public TO logi_app;" | Out-Null
& $PSQL -U postgres -d logitrack_db -c "GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO logi_app;" | Out-Null
& $PSQL -U postgres -d logitrack_db -c "ALTER DEFAULT PRIVILEGES FOR ROLE logi_admin IN SCHEMA public GRANT SELECT, INSERT, UPDATE ON TABLES TO logi_app;" | Out-Null
& $PSQL -U postgres -d logitrack_db -c "REVOKE DELETE ON ALL TABLES IN SCHEMA public FROM logi_app;" | Out-Null

Write-Host "[5/6] Права настроены." -ForegroundColor Green

Write-Host "[6/6] Настройка брандмауэра..." -ForegroundColor Cyan

$fwRule = Get-NetFirewallRule -DisplayName "PostgreSQL 5432" -ErrorAction SilentlyContinue
if (-not $fwRule) {
    New-NetFirewallRule -DisplayName "PostgreSQL 5432" `
        -Direction Inbound -Protocol TCP -LocalPort 5432 -Action Allow | Out-Null
    Write-Host "[6/6] Правило брандмауэра создано." -ForegroundColor Green
} else {
    Write-Host "[6/6] Правило брандмауэра уже существует." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Итоговая проверка" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
& $PSQL -U postgres -c "\l logitrack_db"
& $PSQL -U postgres -c "\du logi_admin"
& $PSQL -U postgres -c "\du logi_app"

Write-Host ""
Write-Host "[ГОТОВО] Развёртывание LogiTrack завершено!" -ForegroundColor Green
Write-Host "  PostgreSQL:     версия $PG_VERSION"
Write-Host "  БД:             logitrack_db"
Write-Host "  Администратор:  logi_admin (пароль: $DB_ADMIN_PASS)"
Write-Host "  Приложение:     logi_app   (пароль: $DB_APP_PASS)"
Write-Host "  Порт:           5432"