@echo off
setlocal EnableExtensions
set "DIR=E:\life-support-mini\poller"
set "STOP=%DIR%\STOP"
set "RUN=%DIR%\RUNNING"

echo Requesting poller stop...
del "%STOP%" >nul 2>&1
echo stop>"%STOP%"

set /a tries=0
:wait
if exist "%RUN%" (
  set /a tries+=1
  if %tries% gtr 30 goto timeout
  timeout /t 1 >nul
  goto wait
)

echo Poller stopped.
exit /b 0

:timeout
echo Timed out waiting for poller to stop. Close its window manually if still open.
exit /b 1
