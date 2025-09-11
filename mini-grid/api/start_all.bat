:: start_all.bat
@echo off
setlocal EnableDelayedExpansion

echo ========================================
echo Closing any stale node processes...
for /f "tokens=2 delims=," %%P in ('tasklist /FI "IMAGENAME eq node.exe" /FO CSV /NH') do (
  echo Killing PID %%~P
  taskkill /PID %%~P /F >nul 2>&1
)

echo ========================================
echo Starting Mini API (port 3001)...
set "MINI_DIR=E:\life-support-mini\api"
set "MINI_LOG=%MINI_DIR%\mini_api"
set "LS_MINI_DB_PATH=E:\life-support-mini\db\mini.db"
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$node=(Get-Command node).Source; Start-Process -WindowStyle Minimized -FilePath $node -ArgumentList 'server.js' -WorkingDirectory '%MINI_DIR%' -RedirectStandardOutput '%MINI_LOG%.out.log' -RedirectStandardError '%MINI_LOG%.err.log'"

echo ========================================
echo Starting Grid API (port 3011)...
set "GRID_DIR=E:\life-support-mini-grid\api"
set "GRID_LOG=%GRID_DIR%\grid_api"
set "LS_GRID_DB_PATH=E:\life-support-mini-grid\db\mini.db"
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$node=(Get-Command node).Source; Start-Process -WindowStyle Minimized -FilePath $node -ArgumentList 'server.js' -WorkingDirectory '%GRID_DIR%' -RedirectStandardOutput '%GRID_LOG%.out.log' -RedirectStandardError '%GRID_LOG%.err.log'"

echo ========================================
echo Opening Prospects page...
start "" "http://127.0.0.1:3005/prospects.html"

echo Done. Both APIs started and UI opened.
pause
endlocal
exit /b 0
