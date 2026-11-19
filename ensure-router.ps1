param(
    [int]$Port = $(if ($env:GEMINI_WEB_PORT -match '^\d+$') { [int]$env:GEMINI_WEB_PORT } else { 8766 })
)

$ErrorActionPreference = 'Continue'
$RootDir = $PSScriptRoot
if (-not $RootDir) { $RootDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
$RouterPy = Join-Path $RootDir 'router.py'
$LogDir = Join-Path $RootDir 'logs'
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
$OutLog = Join-Path $LogDir 'router.out.log'
$ErrLog = Join-Path $LogDir 'router.err.log'

function Test-RouterListening {
    param([int]$TargetPort)
    $listening = Get-NetTCPConnection -LocalPort $TargetPort -State Listen -ErrorAction SilentlyContinue
    if (-not $listening) { return $false }
    try {
        $res = Invoke-RestMethod -Uri "http://127.0.0.1:$TargetPort/health" -TimeoutSec 3
        return ($res.status -eq 'ok')
    } catch {
        return $true
    }
}

$mutex = New-Object System.Threading.Mutex($false, 'Local\GeminiWebApiRouterEnsure')
$acquired = $false
try {
    try { $acquired = $mutex.WaitOne(10000) }
    catch [System.Threading.AbandonedMutexException] { $acquired = $true }

    if (Test-RouterListening -TargetPort $Port) {
        exit 0
    }

    $pyCmd = 'C:\Python312\python.exe'
    if (-not (Test-Path $pyCmd)) {
        $pyCmd = (Get-Command python -ErrorAction SilentlyContinue).Source
    }

    Start-Process -FilePath $pyCmd `
        -ArgumentList "`"$RouterPy`"" `
        -WorkingDirectory $RootDir `
        -WindowStyle Hidden `
        -RedirectStandardOutput $OutLog `
        -RedirectStandardError $ErrLog | Out-Null

    for ($i = 0; $i -lt 45; $i++) {
        Start-Sleep -Milliseconds 500
        if (Test-RouterListening -TargetPort $Port) {
            exit 0
        }
    }
} finally {
    if ($acquired) {
        try { $mutex.ReleaseMutex() } catch {}
    }
    $mutex.Dispose()
}
