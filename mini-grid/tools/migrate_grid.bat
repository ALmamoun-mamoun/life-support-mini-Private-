@echo off
setlocal EnableExtensions
echo =====================================================
echo Preparing self-contained API for life-support-mini-grid
echo =====================================================

REM Base paths
set ROOT=E:\life-support-mini
set GRID=E:\life-support-mini-grid

REM 1. Make API folder inside grid
if not exist "%GRID%\api" (
  mkdir "%GRID%\api"
  echo [OK] Created %GRID%\api
)

REM 2. Copy server.js and related API scripts
if exist "%ROOT%\api\server.js" (
  copy "%ROOT%\api\server.js" "%GRID%\api\" >nul
  echo [OK] Copied server.js
)

REM 3. Copy config files (country/city codes)
if not exist "%GRID%\config" mkdir "%GRID%\config"
copy "%ROOT%\config\*.json" "%GRID%\config\" >nul
echo [OK] Copied config JSONs

REM 4. Copy DB starter (not backups)
if not exist "%GRID%\db" mkdir "%GRID%\db"
copy "%ROOT%\db\mini.db" "%GRID%\db\grid.db" >nul
echo [OK] Copied DB (renamed grid.db)

REM 5. Copy start script template
if exist "%ROOT%\api\start_mini_api.bat" (
  copy "%ROOT%\api\start_mini_api.bat" "%GRID%\api\start_grid_api.bat" >nul
  echo [OK] Copied and renamed API start script
)

REM 6. Adjust references inside copied files
echo [*] Updating file paths...
for %%f in ("%GRID%\api\server.js" "%GRID%\api\start_grid_api.bat") do (
  powershell -Command "(Get-Content '%%f') -replace 'E:\\life-support-mini', 'E:\\life-support-mini-grid' | Set-Content '%%f'"
)

REM 7. Remove old proxy links (if exist)
if exist "%GRID%\proxy" (
  rmdir /s /q "%GRID%\proxy"
  echo [OK] Removed proxy folder (not needed, local now)
)

echo =====================================================
echo Done! Now start API with:
echo   %GRID%\api\start_grid_api.bat
echo =====================================================
pause
endlocal
