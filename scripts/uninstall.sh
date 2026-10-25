#!/bin/bash
# Stops Battery Peek and removes the app and its login item.
set -euo pipefail
LABEL="dev.sougou.battery-peek"
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
pkill -x BatteryPeek 2>/dev/null || true
rm -rf "$HOME/Applications/BatteryPeek.app" "$HOME/Library/LaunchAgents/$LABEL.plist"
echo "Removed Battery Peek."
