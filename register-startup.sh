#!/usr/bin/env bash
# Portable Auto-Start Installer for macOS (launchd) & Linux (systemd --user)
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
chmod +x "$SCRIPT_DIR/start-server.sh" "$SCRIPT_DIR/stop-server.sh"

if [ ! -f "$SCRIPT_DIR/.env" ] && [ -f "$SCRIPT_DIR/.env.example" ]; then
    cp "$SCRIPT_DIR/.env.example" "$SCRIPT_DIR/.env"
fi

if [[ "$OSTYPE" == "darwin"* ]]; then
    PLIST_DIR="$HOME/Library/LaunchAgents"
    PLIST_FILE="$PLIST_DIR/com.antigravity.gemini-web-router.plist"
    LOG_DIR="$HOME/Library/Logs/Antigravity"
    mkdir -p "$PLIST_DIR" "$LOG_DIR"

    cat <<EOF > "$PLIST_FILE"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.antigravity.gemini-web-router</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>${SCRIPT_DIR}/start-server.sh</string>
    </array>
    <key>WorkingDirectory</key>
    <string>${SCRIPT_DIR}</string>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>${LOG_DIR}/gemini-web-router.log</string>
    <key>StandardErrorPath</key>
    <string>${LOG_DIR}/gemini-web-router.err</string>
</dict>
</plist>
EOF
    launchctl unload -w "$PLIST_FILE" 2>/dev/null || true
    launchctl load -w "$PLIST_FILE"
    echo "[SUCCESS] macOS LaunchAgent registered and started: $PLIST_FILE"
else
    UNIT_DIR="$HOME/.config/systemd/user"
    UNIT_FILE="$UNIT_DIR/gemini-web-router.service"
    mkdir -p "$UNIT_DIR"

    cat <<EOF > "$UNIT_FILE"
[Unit]
Description=Gemini Web API Router (Port 8766)
After=network.target

[Service]
Type=simple
WorkingDirectory=${SCRIPT_DIR}
ExecStart=/bin/bash ${SCRIPT_DIR}/start-server.sh
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
EOF
    systemctl --user daemon-reload
    systemctl --user enable --now gemini-web-router.service
    echo "[SUCCESS] Linux systemd user service registered and started: $UNIT_FILE"
fi
