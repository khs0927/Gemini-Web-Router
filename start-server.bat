@echo off
chcp 65001 >nul
cd /d "%~dp0"
if /i "%1"=="/min" (
    start "Gemini Web API Router" /min cmd /c "python router.py"
    exit /b 0
)
echo [Gemini Web API Router] Starting on http://127.0.0.1:8766/v1 ...
python router.py
