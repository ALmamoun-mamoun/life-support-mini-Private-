@echo off
setlocal EnableExtensions EnableDelayedExpansion
title "Life-Support Mini — Rotate Backups ^& Logs"

rem === Config ===
set "BACKUP_DIR=E:\life-support-mini\db\backups"
set "KEEP=30"         rem keep newest N *.db backups
set "MAX_DAYS=0"      rem set >0 to also delete backups older than N days
set "LOG_DIR=E:\life-support-mini\logs"
set "POLL_LOG=%LOG_DIR%\outbox_poller.log"
set "MAX_LOG_MB=5"    rem rotate poller log if larger than this

if not exist "%BACKUP_DIR%" md "%BACKUP_DIR%" >nul 2>&1
if not exist "%LOG_DIR%"    md "%LOG_DIR%"    >nul 2>&1

echo === Backups: %BACKUP_DIR% ===
for /f %%C in ('dir /b /a:-d "%BACKUP_DIR%\*.db" ^| find /c /v ""') do set "COUNT_BEFORE=%%C"
if not defined COUNT_BEFORE set "COUNT_BEFORE=0"
echo Before: %COUNT_BEFORE% files

rem --- Optional age-based prune ---
if %MAX_DAYS% GTR 0 forfiles /p "%BACKUP_DIR%" /m *.db /d -%MAX_DAYS% /c "cmd /c del /q @path" >nul 2>&1

rem --- Count-based prune: keep newest %KEEP% ---
set /a i=0
for /f "delims=" %%F in ('dir /b /a:-d /o-d "%BACKUP_DIR%\*.db"') do (
  set /a i+=1
  if !i! gtr %KEEP% (
    echo Deleting: %%F
    del /q "%BACKUP_DIR%\%%F" >nul 2>&1
  )
)

for /f %%C in ('dir /b /a:-d "%BACKUP_DIR%\*.db" ^| find /c /v ""') do set "COUNT_AFTER=%%C"
if not defined COUNT_AFTER set "COUNT_AFTER=0"
echo After:  %COUNT_AFTER% files
echo.

rem === Poller log rotation ===
if exist "%POLL_LOG%" (
  for %%A in ("%POLL_LOG%") do set "SZ=%%~zA"
  if defined SZ (
    set /a LIMIT=%MAX_LOG_MB%*1024*1024
    if !SZ! GTR !LIMIT! (
      set "STAMP=%DATE:~10,4%%DATE:~4,2%%DATE:~7,2%_%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
      set "STAMP=!STAMP: =0!"
      move /Y "%POLL_LOG%" "%LOG_DIR%\outbox_poller_!STAMP!.log" >nul
      type nul > "%POLL_LOG%"
      echo Rotated poller log to: %LOG_DIR%\outbox_poller_!STAMP!.log
    ) else (
      echo Poller log size OK: !SZ! bytes; limit=%MAX_LOG_MB% MB
    )
  ) else (
    echo Could not determine poller log size.
  )
) else (
  echo Poller log not found; skipping.
)


echo.
echo Rotation complete.
pause
