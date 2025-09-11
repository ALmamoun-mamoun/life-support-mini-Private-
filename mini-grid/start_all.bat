:: start_all.bat (CLEAN GRID VERSION)
@echo off
setlocal EnableDelayedExpansion

echo ========================================
echo Closing any stale node processes...
for /f "tokens=2 delims=," %%P in ('tasklist /FI "IMAGENAME eq node.exe" /FO CSV /NH') do (
  echo Killing PID %%~P
  taskkill /PID %%~P /F >nul 2>&1
)

:: Check if port 3011 is already in use
for /f "tokens=5" %%P in ('netstat -ano ^| findstr ":3011" ^| findstr LISTENING') do (
  echo ERROR: Port 3011 already in use by PID %%P
  pause
  exit /b 1
)

echo ========================================
echo Starting Grid API (port 3011)...
set "GRID_DIR=E:\life-support-mini-grid\api"
set "GRID_LOG=%GRID_DIR%\grid_api"
set "LS_GRID_DB_PATH=E:\life-support-mini-grid\db\grid.db"

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$node='C:\Program Files\nodejs\node.exe'; Start-Process -WindowStyle Minimized -FilePath $node -ArgumentList 'server.js' -WorkingDirectory '%GRID_DIR%' -RedirectStandardOutput '%GRID_LOG%.out.log' -RedirectStandardError '%GRID_LOG%.err.log'"

echo ========================================
echo Opening Grid page...
echo Waiting a few seconds for server to initialize...
timeout /t 3 /nobreak >nul
start "" http://127.0.0.1:3011/grid.html

echo Done. Grid API started and UI opened.
pause
endlocal
exit /b 0
