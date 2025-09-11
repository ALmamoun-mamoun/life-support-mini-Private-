@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem === Paths ===
set "BASE=E:\life-support-mini"
set "DB=%BASE%\db\mini.db"
set "BACKUP_DIR=%BASE%\db\backups"

if not exist "%BACKUP_DIR%" mkdir "%BACKUP_DIR%"

rem === Timestamp (yyyyMMdd_HHmmss, locale-safe via PowerShell) ===
for /f %%t in ('powershell -NoProfile -Command "(Get-Date).ToString(\"yyyyMMdd_HHmmss\")"') do set "ts=%%t"

rem === Make backup ===
copy /y "%DB%" "%BACKUP_DIR%\mini_%ts%.db" >nul

rem === Rotate: keep newest 14 backups by name (timestamped), delete the rest ===
powershell -NoProfile -Command "$dir='%BACKUP_DIR%'; $keep=14; if (Test-Path $dir) { Get-ChildItem -Path $dir -Filter 'mini_*.db' | Sort-Object Name -Descending | Select-Object -Skip $keep | Remove-Item -Force }"

echo Backed up to %BACKUP_DIR%\mini_%ts%.db
echo (kept latest 14 backups)
pause
