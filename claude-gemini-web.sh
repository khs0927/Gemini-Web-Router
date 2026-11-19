#!/usr/bin/env bash
# Launch Claude Code CLI powered directly by Gemini Web Router (http://127.0.0.1:8766)
export ANTHROPIC_BASE_URL="http://127.0.0.1:8766"
export ANTHROPIC_AUTH_TOKEN="local-dev-token"
export ANTHROPIC_API_KEY="local-dev-token"
export ANTHROPIC_MODEL="gemini-4-carbon"
export ANTHROPIC_SMALL_FAST_MODEL="gemini-4-hydrogen"
exec claude "$@"
