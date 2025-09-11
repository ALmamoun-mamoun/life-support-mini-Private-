# Kill old Node.js (server.js) and serve.exe processes, keep the most recent one

$targets = "node.exe", "serve.exe"

foreach ($t in $targets) {
    $procs = Get-Process $t -ErrorAction SilentlyContinue | Sort-Object StartTime
    if ($procs.Count -gt 1) {
        # keep the last (newest) process, kill others
        $kill = $procs[0..($procs.Count-2)]
        foreach ($p in $kill) {
            try {
                Write-Host "Killing old $($p.ProcessName) PID=$($p.Id)"
                Stop-Process -Id $p.Id -Force
            } catch {
                Write-Host "Failed to kill PID=$($p.Id) ($($p.ProcessName))"
            }
        }
        Write-Host "Keeping latest $($t) PID=$($procs[-1].Id)"
    } elseif ($procs) {
        Write-Host "Only one $t running (PID=$($procs.Id))"
    } else {
        Write-Host "No $t running"
    }
}
