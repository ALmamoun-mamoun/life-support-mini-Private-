@echo off
setlocal EnableExtensions
set "URL=http://127.0.0.1:3001/prospecting/prospects.html"
set "API_START=E:\life-support-mini\api\start_mini_api.bat"
set "PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
set "PS_SCRIPT=E:\life-support-mini\proxy\serve_ui.ps1"
set "LOCAL=E:\life-support-mini\prospecting\prospects.html"

rem Is proxy already listening?
set "LISTEN="
for /f "tokens=5" %%P in ('netstat -ano ^| findstr /c:":3005" ^| findstr /c:"LISTENING"') do set "LISTEN=1"

if not defined LISTEN (
  echo Starting Mini API and UI proxy...
  if exist "%API_START%" call "%API_START%" >nul 2>&1
  start "UI Proxy (3005)" "%PS%" -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%"
  timeout /t 2 >nul
)

rem Open the proxied page
start "" "%URL%"

rem Fallback: if proxy still not up in 2s, open the static file
set "LISTEN="
for /f "tokens=5" %%P in ('netstat -ano ^| findstr /c:":3005" ^| findstr /c:"LISTENING"') do set "LISTEN=1"
if not defined LISTEN (
  start "" "%LOCAL%"
)

endlocal

