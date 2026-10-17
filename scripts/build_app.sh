#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "ClipLine is a macOS application. Build it on macOS 13 or later." >&2
  exit 1
fi

swift build -c release
APP="$ROOT/dist/ClipLine.app"
mkdir -p "$APP/Contents/MacOS"
cp "$ROOT/.build/release/ClipLine" "$APP/Contents/MacOS/ClipLine"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>app.clipline.mac</string>
  <key>CFBundleName</key><string>ClipLine</string>
  <key>CFBundleDisplayName</key><string>晾图架 ClipLine</string>
  <key>CFBundleExecutable</key><string>ClipLine</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST
codesign --force --sign - "$APP"
echo "Built: $APP"
echo "Launch with: open '$APP'"
