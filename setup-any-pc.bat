@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo [Gemini Web API Router] Running universal one-click setup and auto-start installer...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0register-startup.ps1"
