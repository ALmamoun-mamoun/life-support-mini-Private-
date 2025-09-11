@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Life-Support Mini — Outbox Poller

rem --- Config ---
set "API=http://127.0.0.1:3001"
set "DRAIN=%API%/event-outbox/drain?limit=50"
set "ROOT=E:\life-support-mini"
set "LOG=%ROOT%\logs\outbox_poller.log"
set "DIR_POLL=%ROOT%\poller"
set "STATE=%DIR_POLL%\RUNNING"
set "STOP=%DIR_POLL%\STOP"

set "CURL=%SystemRoot%\System32\curl.exe"
if not exist "%CURL%" set "CURL=curl"

rem --- Ensure dirs ---
if not exist "%ROOT%\logs"  md "%ROOT%\logs"
if not exist "%DIR_POLL%"   md "%DIR_POLL%"

rem --- Single instance guard ---
rem --- Single instance guard ---
if exist "%STATE%" (
  echo Another poller instance seems to be running [found %STATE%].
  echo If that's not the case, delete the file and run again.
  pause
  exit /b 1
)

echo [%date% %time%] Starting Outbox Poller >> "%LOG%"
echo Polling /event-outbox/drain every 5s. Log: "%LOG%"
echo.>"%STATE%"


echo [%date% %time%] Starting Outbox Poller >> "%LOG%"
echo.>"%STATE%"

:loop
if exist "%STOP%" (
  echo [%date% %time%] STOP file found. Stopping. >> "%LOG%"
  del "%STATE%" >nul 2>&1
  del "%STOP%"  >nul 2>&1
  exit /b 0
)

set "TMP=%TEMP%\outbox_%RANDOM%.json"
"%CURL%" -sS "%DRAIN%" > "%TMP%"

set /p first=<"%TMP%"
if not defined first set "first=?"
>>"%LOG%" echo [%date% %time%] drain -> %first%
type "%TMP%" >> "%LOG%"
>>"%LOG%" echo.

del "%TMP%" >nul 2>&1
timeout /t 5 >nul
goto loop
