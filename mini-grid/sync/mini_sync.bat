@echo off
setlocal
set "ROOT=E:\life-support-mini"
set "SYNC=%ROOT%\sync"
set "CFG=%ROOT%\config\config.mini.json"

if not exist "%CFG%" (
  echo ERROR: Config not found: "%CFG%"
  exit /b 1
)

where python >nul 2>&1
if %errorlevel% neq 0 (
  set "PY=py -3"
) else (
  set "PY=python"
)

"%PY%" "%SYNC%\life_support_api.py" sync --auto --config "%CFG%"
set "rc=%errorlevel%"
if %rc% neq 0 (
  echo Sync failed with exit code %rc%
  exit /b %rc%
)
echo Sync OK.
endlocal
