@echo off
chcp 65001 >nul
REM Launch Claude Code CLI powered directly by Gemini Web Router (http://127.0.0.1:8766)
REM Maps Claude Opus/Sonnet -> Gemini 4 Carbon, Haiku -> Gemini 4 Hydrogen
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0ensure-router.ps1"
set ANTHROPIC_BASE_URL=http://127.0.0.1:8766
set ANTHROPIC_AUTH_TOKEN=local-dev-token
set ANTHROPIC_API_KEY=local-dev-token
set ANTHROPIC_MODEL=gemini-4-carbon
set ANTHROPIC_SMALL_FAST_MODEL=gemini-4-hydrogen
claude %*
