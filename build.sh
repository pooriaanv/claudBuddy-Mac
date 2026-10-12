#!/bin/sh
# Builds ClaudeBuddy, installs it to ~/Applications, installs the hook script to
# ~/.claude-buddy/notify.sh (the path agent hooks call) and restarts the app if it was running.
set -e
cd "$(dirname "$0")"

swift build -c release --product ClaudeBuddy
bin="$(swift build -c release --show-bin-path)/ClaudeBuddy"

app="$HOME/Applications/ClaudeBuddy.app"
mkdir -p "$app/Contents/MacOS"
cp "$bin" "$app/Contents/MacOS/ClaudeBuddy"
mkdir -p "$app/Contents/Resources"
cp scripts/notify.sh "$app/Contents/Resources/notify.sh"   # the app installs it to ~/.claude-buddy on launch
iconset="$(mktemp -d)/AppIcon.iconset"
"$bin" --iconset "$iconset"
iconutil -c icns -o "$app/Contents/Resources/AppIcon.icns" "$iconset"
rm -r "$(dirname "$iconset")"

cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>com.pooria.claudebuddy</string>
  <key>CFBundleName</key><string>ClaudeBuddy</string>
  <key>CFBundleExecutable</key><string>ClaudeBuddy</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.0.1</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST
codesign -s - --force "$app" >/dev/null 2>&1 || true
touch "$app"   # nudge Finder to refresh the icon

mkdir -p "$HOME/.claude-buddy"
cp scripts/notify.sh "$HOME/.claude-buddy/notify.sh"
chmod +x "$HOME/.claude-buddy/notify.sh"

if pgrep -xq ClaudeBuddy; then
  pkill -x ClaudeBuddy; sleep 0.5
  open -g "$app"
  echo "built and restarted $app"
else
  echo "built $app (run: open ~/Applications/ClaudeBuddy.app)"
fi
