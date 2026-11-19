#!/usr/bin/env bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [ ! -f ".env" ] && [ -f ".env.example" ]; then
    cp ".env.example" ".env"
fi

PY_BIN="$(command -v python3 || command -v python)"
if ! "$PY_BIN" -c "import gemini_webapi, fastapi, uvicorn, browser_cookie3" >/dev/null 2>&1; then
    echo "[Gemini Web API Router] Installing Python dependencies..."
    "$PY_BIN" -m pip install -U -r requirements.txt
fi

exec "$PY_BIN" "$SCRIPT_DIR/router.py"
