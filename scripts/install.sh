#!/bin/bash
# Builds the app, installs it to ~/Applications, and starts it at login.
# Also cleans up the old "Battery Peek" install (the app was renamed to Peekaboo).
set -euo pipefail
cd "$(dirname "$0")/.."

LABEL="dev.sougou.peekaboo"
DEST="$HOME/Applications/Peekaboo.app"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
OLD_LABEL="dev.sougou.battery-peek"
OLD_DEST="$HOME/Applications/BatteryPeek.app"
OLD_PLIST="$HOME/Library/LaunchAgents/$OLD_LABEL.plist"

scripts/bundle.sh

# Stop and remove the old Battery Peek and any running copy of this app.
launchctl bootout "gui/$(id -u)/$OLD_LABEL" 2>/dev/null || true
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
pkill -x BatteryPeek 2>/dev/null || true
pkill -x Peekaboo 2>/dev/null || true
rm -rf "$OLD_DEST" "$OLD_PLIST"

# Carry the old config over (your hotkey) if there's no new one yet.
if [ -f "$HOME/.config/battery-peek/config.json" ] && [ ! -f "$HOME/.config/peekaboo/config.json" ]; then
  mkdir -p "$HOME/.config/peekaboo"
  cp "$HOME/.config/battery-peek/config.json" "$HOME/.config/peekaboo/config.json"
  echo "Copied your config to ~/.config/peekaboo/config.json"
fi

mkdir -p "$HOME/Applications" "$HOME/Library/LaunchAgents"
rm -rf "$DEST"
cp -R build/Peekaboo.app "$DEST"

cat > "$PLIST" <<PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key><array><string>$DEST/Contents/MacOS/Peekaboo</string></array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><false/>
  <key>ProcessType</key><string>Interactive</string>
</dict>
</plist>
PLISTEOF

launchctl bootstrap "gui/$(id -u)" "$PLIST"
echo "Installed $DEST and started it. Hold the hotkey to peek: ctrl+opt+B by default, or set \"hotkey\" in ~/.config/peekaboo/config.json."
