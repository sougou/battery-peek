#!/bin/bash
# Builds the app, installs it to ~/Applications, and starts it at login.
set -euo pipefail
cd "$(dirname "$0")/.."

LABEL="dev.sougou.battery-peek"
DEST="$HOME/Applications/BatteryPeek.app"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

scripts/bundle.sh

# Stop any running copy before replacing it.
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
pkill -x BatteryPeek 2>/dev/null || true

mkdir -p "$HOME/Applications" "$HOME/Library/LaunchAgents"
rm -rf "$DEST"
cp -R build/BatteryPeek.app "$DEST"

cat > "$PLIST" <<PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key><array><string>$DEST/Contents/MacOS/BatteryPeek</string></array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><false/>
  <key>ProcessType</key><string>Interactive</string>
</dict>
</plist>
PLISTEOF

launchctl bootstrap "gui/$(id -u)" "$PLIST"
echo "Installed $DEST and started it. Hold the hotkey to peek: ctrl+opt+B by default, or set \"hotkey\" in ~/.config/battery-peek/config.json."
