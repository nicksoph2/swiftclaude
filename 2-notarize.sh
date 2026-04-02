#!/bin/bash
set -e

cd /Users/nicksoph/Documents/Dev/claude/devDiscoverApp

APP_PATH=~/Desktop/ClaudeConfigManagerExport/ClaudeConfigManager.app
ZIP_PATH=~/Desktop/ClaudeConfigManager.zip

if [ ! -d "$APP_PATH" ]; then
  echo "ERROR: App not found at $APP_PATH"
  echo "Run the build script first."
  exit 1
fi

echo "=== Step 1: Zipping the app ==="
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

echo "=== Step 2: Submitting for notarization ==="
echo "(This usually takes 1-5 minutes)"
echo ""
xcrun notarytool submit "$ZIP_PATH" \
  --apple-id "nick@sophocleous.co.uk" \
  --team-id "GUNMZYT3D5" \
  --password "$1" \
  --wait

echo ""
echo "=== Step 3: Stapling the notarization ticket ==="
xcrun stapler staple "$APP_PATH"

echo ""
echo "=== Step 4: Creating final zip to send ==="
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

echo ""
echo "========================================="
echo "DONE! Send this file to your tester:"
echo "  ~/Desktop/ClaudeConfigManager.zip"
echo ""
echo "They just unzip it and double-click. No extra steps needed."
echo "========================================="
