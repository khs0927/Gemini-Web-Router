param(
    [int]$Port = $(if ($env:GEMINI_WEB_PORT -match '^\d+$') { [int]$env:GEMINI_WEB_PORT } else { 8766 })
)

$ErrorActionPreference = 'Continue'
$RootDir = $PSScriptRoot
if (-not $RootDir) { $RootDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
$RouterPy = Join-Path $RootDir 'router.py'
$ReqFile = Join-Path $RootDir 'requirements.txt'
$LogDir = Join-Path $RootDir 'logs'
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
$OutLog = Join-Path $LogDir 'router.out.log'
$ErrLog = Join-Path $LogDir 'router.err.log'

function Find-PythonExe {
    $candidates = @(
        (Join-Path $RootDir '.venv\Scripts\python.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Python\Python312\python.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Python\Python313\python.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Python\Python311\python.exe'),
        'C:\Python312\python.exe',
        'C:\Python313\python.exe',
        'C:\Python311\python.exe'
    )
    foreach ($c in $candidates) {
        if ($c -and (Test-Path -LiteralPath $c)) { return $c }
    }
    $cmd = Get-Command python -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source -and ($cmd.Source -notmatch 'WindowsApps')) {
        return $cmd.Source
    }
    $pyLauncher = Get-Command py -ErrorAction SilentlyContinue
    if ($pyLauncher) {
        try {
            $resolved = & py -3 -c "import sys; print(sys.executable)" 2>$null
            if ($resolved -and (Test-Path -LiteralPath $resolved.Trim())) {
                return $resolved.Trim()
            }
        } catch {}
    }
    return $null
}

function Test-RouterListening {
    param([int]$TargetPort)
    $listening = Get-NetTCPConnection -LocalPort $TargetPort -State Listen -ErrorAction SilentlyContinue
    if (-not $listening) { return $false }
    try {
        $res = Invoke-RestMethod -Uri "http://127.0.0.1:$TargetPort/health" -TimeoutSec 3
        return ($res.status -eq 'ok' -or $res.status -eq 'degraded')
    } catch {
        return $true
    }
}

$mutex = New-Object System.Threading.Mutex($false, 'Local\GeminiWebApiRouterEnsure')
$acquired = $false
try {
    try { $acquired = $mutex.WaitOne(15000) }
    catch [System.Threading.AbandonedMutexException] { $acquired = $true }

    if (Test-RouterListening -TargetPort $Port) {
        exit 0
    }

    $pyCmd = Find-PythonExe
    if (-not $pyCmd) {
        Add-Content -LiteralPath $ErrLog -Value "$(Get-Date -Format o) [ERROR] Python 3.11+ executable not found on this machine."
        exit 1
    }

    # Auto-install dependencies if gemini_webapi or fastapi is missing on this computer
    & $pyCmd -c "import gemini_webapi, fastapi, uvicorn, browser_cookie3" 2>$null
    if ($LASTEXITCODE -ne 0 -and (Test-Path -LiteralPath $ReqFile)) {
        Add-Content -LiteralPath $OutLog -Value "$(Get-Date -Format o) [BOOTSTRAP] Installing requirements.txt via $pyCmd ..."
        & $pyCmd -m pip install -U -r $ReqFile *>> $OutLog
    }

    # Clean up any leftover non-listening router.py processes
    $listenPids = @(Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue | Select-Object -ExpandProperty OwningProcess)
    $stale = Get-CimInstance Win32_Process -Filter "Name = 'python.exe'" -ErrorAction SilentlyContinue | Where-Object {
        $_.CommandLine -match 'Gemini-Web-Router.*router\.py' -and ($listenPids -notcontains $_.ProcessId)
    }
    foreach ($proc in $stale) {
        try { Stop-Process -Id $proc.ProcessId -Force -ErrorAction SilentlyContinue } catch {}
    }

    # Launch completely hidden via WScript.Shell so it survives parent shell exit across all Windows machines
    $wsh = New-Object -ComObject WScript.Shell
    $wsh.CurrentDirectory = $RootDir
    $cmdLine = "cmd.exe /c `"`"$pyCmd`" `"$RouterPy`" >> `"$OutLog`" 2>> `"$ErrLog`"`""
    $wsh.Run($cmdLine, 0, $false) | Out-Null

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
