@echo off
set "SCRIPT=E:\life-support-mini\tools\chrome_toast_beep.ahk"
for %%A in (
  "C:\Program Files\AutoHotkey\AutoHotkey.exe"
  "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe"
  "C:\Program Files (x86)\AutoHotkey\AutoHotkey.exe"
) do (
  if exist "%%~A" ( start "" "%%~A" "%SCRIPT%" & echo started beeper & exit /b 0 )
)
echo AutoHotkey not found. Install AutoHotkey, then run this again:
echo   E:\life-support-mini\tools\start_beeper.bat
pause
