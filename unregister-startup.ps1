# Unregister Auto-Start for Gemini Web API Router (Windows)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = 'SilentlyContinue'

$StartupFolder = [Environment]::GetFolderPath('Startup')
$StartupVbs = Join-Path $StartupFolder 'gemini-web-api-router.vbs'
if (Test-Path -LiteralPath $StartupVbs) {
    Remove-Item -LiteralPath $StartupVbs -Force
    Write-Host "Removed Startup VBS: $StartupVbs" -ForegroundColor Green
}

$RunRegPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
if (Get-ItemProperty -Path $RunRegPath -Name 'GeminiWebApiRouter' -ErrorAction SilentlyContinue) {
    Remove-ItemProperty -Path $RunRegPath -Name 'GeminiWebApiRouter' -Force
    Write-Host "Removed HKCU Registry Run key: GeminiWebApiRouter" -ForegroundColor Green
}

$TaskName = "Gemini Web API Router"
& schtasks.exe /Delete /TN $TaskName /F 2>$null | Out-Null
Write-Host "Auto-start unregistration complete." -ForegroundColor Green
