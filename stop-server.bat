@echo off
chcp 65001 >nul
echo [Gemini Web API Router] Stopping port 8766 process...
powershell -NoProfile -Command "$conns = Get-NetTCPConnection -LocalPort 8766 -State Listen -ErrorAction SilentlyContinue; foreach ($c in $conns) { Stop-Process -Id $c.OwningProcess -Force -ErrorAction SilentlyContinue }"
echo [Gemini Web API Router] Stopped.
