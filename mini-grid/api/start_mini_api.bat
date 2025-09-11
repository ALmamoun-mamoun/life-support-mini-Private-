@echo off
setlocal
set "LS_MINI_DB_PATH=E:\life-support-mini\db\mini.db"

REM Use PowerShell to: skip if 3001 is listening, find node.exe, start minimized and log (two separate files).
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$p=(Get-NetTCPConnection -State Listen -LocalPort 3001 -ErrorAction SilentlyContinue | Select-Object -Expand OwningProcess -Unique); if($p){ Write-Host ('Mini API already running on port 3001 (PID {0}). Skipping start.' -f $p); exit 0 }; " ^
  "$node=(Get-Command node -ErrorAction SilentlyContinue).Source; if(-not $node){ if(Test-Path 'C:\Program Files\nodejs\node.exe'){ $node='C:\Program Files\nodejs\node.exe' } elseif(Test-Path 'C:\Program Files (x86)\nodejs\node.exe'){ $node='C:\Program Files (x86)\nodejs\node.exe' } else { Write-Error 'node.exe not found in PATH or common install dirs'; exit 1 } }; " ^
  "Start-Process -WindowStyle Minimized -FilePath $node -ArgumentList 'server.js' -WorkingDirectory 'E:\life-support-mini\api' -RedirectStandardOutput 'E:\life-support-mini\api\mini_api.out.log' -RedirectStandardError 'E:\life-support-mini\api\mini_api.err.log'"

exit /b 0
