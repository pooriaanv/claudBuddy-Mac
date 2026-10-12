#!/bin/sh
# Builds the app and zips it for a GitHub release: dist/ClaudeBuddy-<version>.zip
set -e
cd "$(dirname "$0")/.."
./build.sh
version=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$HOME/Applications/ClaudeBuddy.app/Contents/Info.plist")
mkdir -p dist
zip="dist/ClaudeBuddy-$version.zip"
rm -f "$zip"
ditto -c -k --norsrc --noextattr --noacl --keepParent "$HOME/Applications/ClaudeBuddy.app" "$zip"
echo "packaged $zip"
