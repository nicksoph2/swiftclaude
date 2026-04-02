#!/bin/bash
set -e

cd /Users/nicksoph/Documents/Dev/claude/devDiscoverApp

echo "=== Step 1: Cleaning up any previous build ==="
rm -rf ~/Desktop/ClaudeConfigManager.xcarchive
rm -rf ~/Desktop/ClaudeConfigManagerExport

echo "=== Step 2: Archiving the app (with hardened runtime) ==="
xcodebuild archive \
  -project ClaudeConfigManager/ClaudeConfigManager.xcodeproj \
  -scheme ClaudeConfigManager \
  -destination 'platform=macOS' \
  -archivePath ~/Desktop/ClaudeConfigManager.xcarchive \
  OTHER_CODE_SIGN_FLAGS="--options=runtime"

echo ""
echo "=== Step 3: Exporting signed app ==="
xcodebuild -exportArchive \
  -archivePath ~/Desktop/ClaudeConfigManager.xcarchive \
  -exportPath ~/Desktop/ClaudeConfigManagerExport \
  -exportOptionsPlist /Users/nicksoph/Documents/Dev/claude/devDiscoverApp/ExportOptions.plist

echo ""
echo "========================================="
echo "SUCCESS! Your signed app is at:"
echo "  ~/Desktop/ClaudeConfigManagerExport/ClaudeConfigManager.app"
echo ""
echo "Next step: run the notarize script."
echo "========================================="
