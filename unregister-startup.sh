#!/usr/bin/env bash
set -e
if [[ "$OSTYPE" == "darwin"* ]]; then
    PLIST_FILE="$HOME/Library/LaunchAgents/com.antigravity.gemini-web-router.plist"
    launchctl unload -w "$PLIST_FILE" 2>/dev/null || true
    rm -f "$PLIST_FILE"
    echo "[SUCCESS] Removed macOS LaunchAgent."
else
    systemctl --user disable --now gemini-web-router.service 2>/dev/null || true
    rm -f "$HOME/.config/systemd/user/gemini-web-router.service"
    systemctl --user daemon-reload
    echo "[SUCCESS] Removed Linux systemd user service."
fi
