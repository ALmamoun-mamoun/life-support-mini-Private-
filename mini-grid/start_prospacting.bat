@echo off
setlocal EnableExtensions

rem Paths
set "ROOT=E:\life-support-mini"
set "API_START=%ROOT%\api\start_mini_api.bat"
set "PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
set "PS_SCRIPT=%ROOT%\proxy\serve_ui.ps1"
set "LOCAL=%ROOT%\prospecting\prospects.html"
set "URL=http://127.0.0.1:3005/prospects.html"

echo Checking if API (Node) is running...
for /f "tokens=5" %%P in ('netstat -ano ^| findstr /c:":3001" ^| findstr /c:"LISTENING"') do set "API_RUNNING=1"

if not defined API_RUNNING (
  echo Starting Mini API...
  if exist "%API_START%" call "%API_START%" >nul 2>&1
  timeout /t 2 >nul
)

echo Checking if proxy (serve_ui.ps1) is running...
for /f "tokens=5" %%P in ('netstat -ano ^| findstr /c:":3005" ^| findstr /c:"LISTENING"') do set "PROXY_RUNNING=1"

if not defined PROXY_RUNNING (
  echo Starting UI Proxy (port 3005)...
  start "UI Proxy (3005)" "%PS%" -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%"
  timeout /t 2 >nul
)

echo Opening page...
start "" "%URL%"

endlocal
