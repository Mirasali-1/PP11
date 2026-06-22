#Requires -RunAsAdministrator

$PG_BIN      = "C:\Program Files\PostgreSQL\17\bin"
$DB_NAME     = "logitrack_db"
$DB_USER     = "postgres"
$DB_PASS     = "admin123"
$BACKUP_DIR  = "C:\logitrack\backups"
$TIMESTAMP   = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$BACKUP_FILE = "$BACKUP_DIR\${DB_NAME}_$TIMESTAMP.backup"

if (-not (Test-Path $BACKUP_DIR)) {
    New-Item -ItemType Directory -Path $BACKUP_DIR | Out-Null
}

$env:PGPASSWORD = $DB_PASS

Write-Host "Starting backup of $DB_NAME..." -ForegroundColor Cyan

& "$PG_BIN\pg_dump.exe" -U $DB_USER -d $DB_NAME -F c -f $BACKUP_FILE

if ($LASTEXITCODE -eq 0) {
    $SIZE = [math]::Round((Get-Item $BACKUP_FILE).Length / 1KB, 2)
    Write-Host "Backup completed: $BACKUP_FILE ($SIZE KB)" -ForegroundColor Green
} else {
    Write-Host "Backup failed!" -ForegroundColor Red
    exit 1
}
