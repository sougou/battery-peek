#!/bin/bash
# Builds build/BatteryPeek.app (a menu-bar app with no Dock icon), ad-hoc signed.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release --product BatteryPeek 2>&1 | grep -v "ld: warning" | grep -E "error|Build complete|Compiling" | tail -3

APP=build/BatteryPeek.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/BatteryPeek "$APP/Contents/MacOS/BatteryPeek"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>dev.sougou.battery-peek</string>
  <key>CFBundleName</key><string>Battery Peek</string>
  <key>CFBundleDisplayName</key><string>Battery Peek</string>
  <key>CFBundleExecutable</key><string>BatteryPeek</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST
# Ad-hoc signature: enough to run locally. A rebuild changes it, so macOS permissions
# granted to an older build (such as Input Monitoring) must be granted again.
codesign --force --deep --sign - "$APP" 2>&1 | tail -1
echo "Built $APP"
