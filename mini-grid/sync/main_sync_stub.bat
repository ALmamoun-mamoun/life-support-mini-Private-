
@echo off
:: sync_main.bat - Main-only Import / Export / Sync (auto-init)
setlocal ENABLEDELAYEDEXPANSION
cd /d "%~dp0"

set "CFG=config.main.json"
if not exist "%CFG%" (
  echo ERROR: %CFG% not found in %cd%
  exit /b 1
)

if not exist inbox mkdir inbox
if not exist outbox mkdir outbox

echo === Main init ===
life-support-api.exe init --role main --config "%CFG%" --schema "init_db.sql"
if errorlevel 1 exit /b 1

echo === Import from inbox ===
for %%F in (inbox\*.lsx) do (
  echo Importing %%F ...
  life-support-api.exe import --file "%%F" --config "%CFG%"
  if !errorlevel! EQU 0 del "%%F"
)

for /f "tokens=1-4 delims=/ " %%a in ('date /t') do set d=%%d-%%b-%%c
for /f "tokens=1-3 delims=:." %%a in ("%time%") do set t=%%a%%b%%c
set "filename=bundle_%d%_%t%.lsx"
echo === Export to outbox\%filename% ===
life-support-api.exe export --scope assigned --out "outbox\%filename%" --config "%CFG%"
if errorlevel 1 exit /b 1

echo Done (Main).
endlocal
