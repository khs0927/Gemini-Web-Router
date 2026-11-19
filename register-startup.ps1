# Portable Auto-Start & Provider Installer for Gemini Web API Router (Windows)
# Works identically on any Windows computer regardless of username, admin privileges, or clone folder path.
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = 'Continue'

$RootDir = $PSScriptRoot
if (-not $RootDir) { $RootDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
$EnsureScript = Join-Path $RootDir 'ensure-router.ps1'
$HiddenVbs = Join-Path $RootDir 'start-router-hidden.vbs'
$EnvFile = Join-Path $RootDir '.env'
$EnvExample = Join-Path $RootDir '.env.example'

Write-Host "=== [1/4] Initializing portable configuration (.env) ===" -ForegroundColor Cyan
if (-not (Test-Path -LiteralPath $EnvFile) -and (Test-Path -LiteralPath $EnvExample)) {
    Copy-Item -LiteralPath $EnvExample -Destination $EnvFile -Force
    Write-Host "  -> Created .env from .env.example" -ForegroundColor Green
}

Write-Host "=== [2/4] Registering Windows Startup Folder VBS & Registry Run Key ===" -ForegroundColor Cyan
$StartupFolder = [Environment]::GetFolderPath('Startup')
$StartupVbs = Join-Path $StartupFolder 'gemini-web-api-router.vbs'

$vbsLines = @(
    'Dim WshShell, fso, ensureScript, psExe',
    'Set WshShell = CreateObject("WScript.Shell")',
    'Set fso = CreateObject("Scripting.FileSystemObject")',
    'psExe = WshShell.ExpandEnvironmentStrings("%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe")',
    "ensureScript = `"$EnsureScript`"",
    'If fso.FileExists(psExe) And fso.FileExists(ensureScript) Then',
    "    WshShell.CurrentDirectory = `"$RootDir`"",
    '    WshShell.Run """" & psExe & """ -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & ensureScript & """", 0, False',
    'End If'
)
[System.IO.File]::WriteAllText($StartupVbs, ($vbsLines -join "`r`n"), [System.Text.Encoding]::Default)
Write-Host "  -> Startup Folder VBS registered: $StartupVbs" -ForegroundColor Green

$RunRegPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$wscriptExe = "$env:SystemRoot\System32\wscript.exe"
Set-ItemProperty -Path $RunRegPath -Name 'GeminiWebApiRouter' -Value "`"$wscriptExe`" `"$HiddenVbs`"" -Force
Write-Host "  -> HKCU Registry Run key 'GeminiWebApiRouter' registered" -ForegroundColor Green

Write-Host "=== [3/4] Registering Windows Scheduled Task (5-min Watchdog) ===" -ForegroundColor Cyan
$TaskName = "Gemini Web API Router"
& schtasks.exe /Create /TN $TaskName /TR "`"$wscriptExe`" `"$HiddenVbs`"" /SC MINUTE /MO 5 /F 2>$null | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Host "  -> Scheduled Task '$TaskName' registered (Every 5m watchdog)" -ForegroundColor Green
} else {
    Write-Host "  -> Standard user mode: Startup VBS + HKCU Run key active (Admin not required)" -ForegroundColor Green
}

Write-Host "=== [4/4] Registering Providers (Aside / OpenCode / ZCode) & Starting Router ===" -ForegroundColor Cyan
$asideInstaller = Join-Path $RootDir 'configs\install-aside-config.js'
$nodeCmd = (Get-Command node -ErrorAction SilentlyContinue).Source
if ($nodeCmd -and (Test-Path -LiteralPath $asideInstaller)) {
    & $nodeCmd $asideInstaller
}

$ocInstaller = Join-Path $RootDir 'configs\setup-opencode.ps1'
if (Test-Path -LiteralPath $ocInstaller) {
    & $ocInstaller
}

$zcInstaller = Join-Path $RootDir 'configs\setup-zcode.ps1'
if (Test-Path -LiteralPath $zcInstaller) {
    & $zcInstaller
}

& $EnsureScript
Start-Sleep -Seconds 2
try {
    $health = Invoke-RestMethod -Uri "http://127.0.0.1:8766/health" -TimeoutSec 5
    Write-Host "`n[SUCCESS] Gemini Web API Router is ONLINE on http://127.0.0.1:8766/v1 (status=$($health.status))" -ForegroundColor Green
} catch {
    Write-Host "`n[INFO] Gemini Web API Router startup triggered in background. Check logs\router.out.log." -ForegroundColor Yellow
}
