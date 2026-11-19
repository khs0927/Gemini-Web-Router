#!/usr/bin/env bash
PORT="${GEMINI_WEB_PORT:-8766}"
PID=$(lsof -ti tcp:"$PORT" || true)
if [ -n "$PID" ]; then
    kill -9 $PID
    echo "[Gemini Web API Router] Stopped process $PID on port $PORT."
else
    echo "[Gemini Web API Router] No process listening on port $PORT."
fi
