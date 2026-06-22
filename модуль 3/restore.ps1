#Requires -RunAsAdministrator

$PG_BIN     = "C:\Program Files\PostgreSQL\17\bin"
$DB_NAME    = "logitrack_db"
$DB_USER    = "postgres"
$DB_PASS    = "admin123"
$BACKUP_DIR = "C:\logitrack\backups"

$env:PGPASSWORD = $DB_PASS

$BACKUP_FILE = Get-ChildItem -Path $BACKUP_DIR -Filter "*.backup" |
               Sort-Object LastWriteTime -Descending |
               Select-Object -First 1 -ExpandProperty FullName

if ([string]::IsNullOrEmpty($BACKUP_FILE)) {
    Write-Host "No backup files found in $BACKUP_DIR" -ForegroundColor Red
    exit 1
}

Write-Host "Restoring $DB_NAME from $BACKUP_FILE..." -ForegroundColor Cyan

& "$PG_BIN\psql.exe" -U $DB_USER -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$DB_NAME' AND pid <> pg_backend_pid();" | Out-Null
& "$PG_BIN\psql.exe" -U $DB_USER -c "DROP DATABASE IF EXISTS $DB_NAME;"
& "$PG_BIN\psql.exe" -U $DB_USER -c "CREATE DATABASE $DB_NAME OWNER logi_admin ENCODING 'UTF8';"

& "$PG_BIN\pg_restore.exe" -U $DB_USER -d $DB_NAME -F c $BACKUP_FILE

if ($LASTEXITCODE -eq 0) {
    Write-Host "Restore completed successfully!" -ForegroundColor Green
} else {
    Write-Host "Restore failed!" -ForegroundColor Red
    exit 1
}
