# Register Gemini-Web-Local provider into ZCode (~/.zcode/v2/config.json)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$configDir = Join-Path $env:USERPROFILE ".zcode\v2"
if (-not (Test-Path $configDir)) {
    New-Item -ItemType Directory -Path $configDir -Force | Out-Null
}
$targetConfigFile = Join-Path $configDir "config.json"

$providerDef = [PSCustomObject]@{
    npm = "@ai-sdk/openai-compatible"
    name = "Gemini Web Router (gemini.google.com)"
    options = [PSCustomObject]@{
        apiKey = "local-dev-token"
        baseURL = "http://127.0.0.1:8766/v1"
    }
    models = [PSCustomObject]@{
        "gemini-4-carbon" = [PSCustomObject]@{
            name = "Gemini 4 Carbon (Code & Complex Tasks)"
            reasoning = $true
            tool_call = $true
            limit = [PSCustomObject]@{ context = 1048576; output = 65536 }
        }
        "gemini-4-neon" = [PSCustomObject]@{
            name = "Gemini 4 Neon (Deep Analysis)"
            reasoning = $true
            tool_call = $true
            limit = [PSCustomObject]@{ context = 1048576; output = 65536 }
        }
        "gemini-4-hydrogen" = [PSCustomObject]@{
            name = "Gemini 4 Hydrogen (Fast Daily)"
            reasoning = $false
            tool_call = $true
            limit = [PSCustomObject]@{ context = 1048576; output = 65536 }
        }
        "gemini-auto" = [PSCustomObject]@{
            name = "Gemini Auto Mode"
            reasoning = $true
            tool_call = $true
            limit = [PSCustomObject]@{ context = 1048576; output = 65536 }
        }
    }
}

$utf8NoBom = New-Object System.Text.UTF8Encoding $false

if (Test-Path $targetConfigFile) {
    Copy-Item $targetConfigFile "$targetConfigFile.bak" -Force
    $existing = Get-Content $targetConfigFile -Raw -Encoding utf8 | ConvertFrom-Json
    if (-not $existing.provider) {
        $existing | Add-Member -NotePropertyName "provider" -NotePropertyValue ([PSCustomObject]@{}) -Force
    }
    $existing.provider | Add-Member -NotePropertyName "gemini-web-local" -NotePropertyValue $providerDef -Force
    [System.IO.File]::WriteAllText($targetConfigFile, ($existing | ConvertTo-Json -Depth 10), $utf8NoBom)
} else {
    $newObj = [PSCustomObject]@{
        provider = [PSCustomObject]@{
            "gemini-web-local" = $providerDef
        }
    }
    [System.IO.File]::WriteAllText($targetConfigFile, ($newObj | ConvertTo-Json -Depth 10), $utf8NoBom)
}

Write-Host "[SUCCESS] ZCode provider 'gemini-web-local' (http://127.0.0.1:8766/v1) registered!" -ForegroundColor Green
