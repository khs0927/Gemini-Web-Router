# Register Gemini Web Router into Claude Code (~/.claude.json MCP, ~/.claude/agents/gemini-web-agent.md, and global claude-gemini-web launcher)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = 'Continue'

$ConfigDir = $PSScriptRoot
if (-not $ConfigDir) { $ConfigDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
$RootDir = Split-Path -Parent $ConfigDir
$McpPy = Join-Path $RootDir 'mcp_server.py'
$LauncherCmd = Join-Path $RootDir 'claude-gemini-web.cmd'

function Find-PythonExe {
    foreach ($c in @(
        (Join-Path $RootDir '.venv\Scripts\python.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Python\Python312\python.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Python\Python313\python.exe'),
        'C:\Python312\python.exe',
        'C:\Python313\python.exe'
    )) {
        if ($c -and (Test-Path -LiteralPath $c)) { return $c }
    }
    $cmd = Get-Command python -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source -and ($cmd.Source -notmatch 'WindowsApps')) { return $cmd.Source }
    return 'python'
}

$pyExe = Find-PythonExe
$utf8NoBom = New-Object System.Text.UTF8Encoding $false

# 1. Register `gemini-web` MCP server in ~/.claude.json
$claudeJsonPath = Join-Path $env:USERPROFILE '.claude.json'
if (Test-Path -LiteralPath $claudeJsonPath) {
    try {
        Copy-Item -LiteralPath $claudeJsonPath -Destination "$claudeJsonPath.bak-geminiweb" -Force
        $claudeObj = Get-Content -LiteralPath $claudeJsonPath -Raw -Encoding utf8 | ConvertFrom-Json
    } catch {
        $claudeObj = [PSCustomObject]@{}
    }
} else {
    $claudeObj = [PSCustomObject]@{}
}

if (-not $claudeObj.mcpServers) {
    $claudeObj | Add-Member -NotePropertyName 'mcpServers' -NotePropertyValue ([PSCustomObject]@{}) -Force
}

$mcpDef = [PSCustomObject]@{
    type = 'stdio'
    command = $pyExe
    args = @($McpPy)
    env = [PSCustomObject]@{
        GEMINI_WEB_ROUTER_URL = 'http://127.0.0.1:8766'
    }
}
$claudeObj.mcpServers | Add-Member -NotePropertyName 'gemini-web' -NotePropertyValue $mcpDef -Force
[System.IO.File]::WriteAllText($claudeJsonPath, ($claudeObj | ConvertTo-Json -Depth 15), $utf8NoBom)
Write-Host "[Claude Code] Registered 'gemini-web' MCP server in $claudeJsonPath" -ForegroundColor Green

# 2. Install ~/.claude/agents/gemini-web-agent.md
$claudeAgentsDir = Join-Path $env:USERPROFILE '.claude\agents'
if (-not (Test-Path -LiteralPath $claudeAgentsDir)) {
    New-Item -ItemType Directory -Path $claudeAgentsDir -Force | Out-Null
}
$agentMdPath = Join-Path $claudeAgentsDir 'gemini-web-agent.md'
$agentMdContent = @"
---
name: gemini-web-agent
description: Delegates a task to Google Gemini Web Router (gemini.google.com Pro quota on local port 8766; default gemini-4-carbon for coding/complex tasks; also gemini-4-neon for deep analysis, gemini-4-hydrogen for fast tasks, and gemini-auto). Use when the user asks for Gemini Web, gemini.google.com quota, Gemini 4 Carbon/Neon, or wants a fast second opinion from Gemini Web (~2-4s per call, 2400 credits/5h).
tools: mcp__gemini-web__gemini_web_ask, mcp__gemini-web__gemini_web_quota, mcp__gemini-web__gemini_web_models, mcp__aside-models__aside_ask, mcp__aside-models__aside_models_list, Read, Grep, Glob
model: opus
---

You are a relay that executes tasks with **Google Gemini Web Router (`gemini.google.com`)**, not by yourself.

1. Collect only the context the task needs (Read/Grep/Glob). The external model cannot see files, so put the needed code and text into the prompt.
2. Call `mcp__gemini-web__gemini_web_ask` (or `mcp__aside-models__aside_ask` with `provider: "gemini-web"`). Pass `model` (`gemini-4-carbon`, `gemini-4-neon`, `gemini-4-hydrogen`, `gemini-auto`).
3. To check remaining 5-hour / weekly credits on gemini.google.com, call `mcp__gemini-web__gemini_web_quota`.
4. Report: first line `[Gemini Web / <model>]`, then the model's answer as is.

Never put secrets (API keys, tokens, cookies, passwords) in the prompt.
"@
[System.IO.File]::WriteAllText($agentMdPath, $agentMdContent, $utf8NoBom)
Write-Host "[Claude Code] Installed subagent: $agentMdPath" -ForegroundColor Green

# 3. Install global `claude-gemini-web.cmd` in ~/.local/bin so user can run `claude-gemini-web` anywhere
$localBin = Join-Path $env:USERPROFILE '.local\bin'
if (Test-Path -LiteralPath $localBin) {
    $globalCmd = Join-Path $localBin 'claude-gemini-web.cmd'
    $cmdBody = @"
@echo off
chcp 65001 >nul
powershell -NoProfile -ExecutionPolicy Bypass -File "$RootDir\ensure-router.ps1"
set ANTHROPIC_BASE_URL=http://127.0.0.1:8766
set ANTHROPIC_AUTH_TOKEN=local-dev-token
set ANTHROPIC_API_KEY=local-dev-token
set ANTHROPIC_MODEL=gemini-4-carbon
set ANTHROPIC_SMALL_FAST_MODEL=gemini-4-hydrogen
claude %*
"@
    [System.IO.File]::WriteAllText($globalCmd, $cmdBody, [System.Text.Encoding]::Default)
    Write-Host "[Claude Code] Installed global CLI launcher: $globalCmd" -ForegroundColor Green
}
