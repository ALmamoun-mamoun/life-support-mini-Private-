@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Life-Support Mini — Restore DB

rem --- Paths ---
set "DB=E:\life-support-mini\db\mini.db"
set "BACKUP_DIR=E:\life-support-mini\db\backups"
set "API_START=E:\life-support-mini\api\start_mini_api.bat"
set "API_STOP=E:\life-support-mini\api\stop_mini_api.bat"
set "BACKUP_BAT=E:\life-support-mini\tools\backup_db.bat"

echo ===============================================
echo  Life-Support Mini — Restore Database
echo  DB:       %DB%
echo  Backups:  %BACKUP_DIR%
echo ===============================================
echo.

if not exist "%BACKUP_DIR%\*.db" (
  echo [ERROR] No backups found in "%BACKUP_DIR%".
  pause
  exit /b 1
)

echo Recent backups:
set /a i=0
for /f "delims=" %%F in ('dir /b /a:-d /o-d "%BACKUP_DIR%\*.db"') do (
  set /a i+=1
  set "file!i!=%%F"
  echo   !i!. %%F
  if !i! geq 50 goto after_list
)
:after_list
echo.

:choose
set /p "n=Enter the number to restore (1-!i!) or Q to quit: "
if /i "%n%"=="Q" exit /b 0

rem validate numeric
for /f "delims=0123456789" %%A in ("%n%") do (
  echo Invalid number.
  goto choose
)
if %n% LSS 1 goto choose
if %n% GTR %i% goto choose

set "BACKUP=%BACKUP_DIR%\!file%n%!"
echo You chose: "!BACKUP!"
set /p "ok=Confirm restore? This will OVERWRITE mini.db. (Y/N): "
if /i not "%ok%"=="Y" (
  echo Aborted.
  pause
  exit /b 0
)

echo.
echo [1/4] Safety backup of current DB...
if exist "%BACKUP_BAT%" (
  call "%BACKUP_BAT%"
) else (
  if exist "%DB%" (
    set "STAMP=%DATE:~10,4%%DATE:~4,2%%DATE:~7,2%_%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
    set "STAMP=%STAMP: =0%"
    copy /Y "%DB%" "%BACKUP_DIR%\mini_pre_restore_%STAMP%.db" >nul
  )
)

echo [2/4] Stopping API...
if exist "%API_STOP%" call "%API_STOP%"

echo [3/4] Restoring DB from "!BACKUP!" ...
copy /Y "!BACKUP!" "%DB%"
if errorlevel 1 (
  echo [ERROR] Restore failed.
  pause
  exit /b 1
)

echo [4/4] Starting API...
if exist "%API_START%" call "%API_START%"

echo.
echo Done. DB restored from:
echo   !BACKUP!
echo.
pause
