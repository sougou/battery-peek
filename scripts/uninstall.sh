#!/bin/bash
# Stops Peekaboo and removes the app and its login item, including the old "Battery Peek" names.
set -euo pipefail
for LABEL in dev.sougou.peekaboo dev.sougou.battery-peek; do
  launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
  rm -f "$HOME/Library/LaunchAgents/$LABEL.plist"
done
pkill -x Peekaboo 2>/dev/null || true
pkill -x BatteryPeek 2>/dev/null || true
rm -rf "$HOME/Applications/Peekaboo.app" "$HOME/Applications/BatteryPeek.app"
echo "Removed Peekaboo."
