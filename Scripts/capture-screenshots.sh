#!/bin/bash
# capture-screenshots.sh
# Runs the UI screenshot tests and extracts images into the Help Book.
#
# Usage:
#   cd <project-root>
#   bash Scripts/capture-screenshots.sh
#
# Prerequisites:
#   - Xcode 16+ with command-line tools
#   - XcodeGen must have been run (xcodegen generate from ClaudeConfigManager/)
#   - The app must build successfully
#   - Accessibility permissions for Xcode Helper (System Settings → Privacy → Accessibility)

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RESULT_BUNDLE="${PROJECT_ROOT}/ScreenshotResults.xcresult"
HELP_IMAGES="${PROJECT_ROOT}/ClaudeConfigManager/Resources/ClaudeConfigManager.help/Contents/Resources/en.lproj/images"

echo "=== Claude Config Manager — Screenshot Capture ==="
echo ""

# Clean previous results
rm -rf "$RESULT_BUNDLE"
mkdir -p "$HELP_IMAGES"

# Step 1: Run UI tests
echo "Step 1: Running screenshot UI tests..."
xcodebuild test \
    -project "${PROJECT_ROOT}/ClaudeConfigManager/ClaudeConfigManager.xcodeproj" \
    -scheme ClaudeConfigManager \
    -destination 'platform=macOS' \
    -only-testing:ClaudeConfigManagerUITests/ScreenshotCaptureTests \
    -resultBundlePath "$RESULT_BUNDLE" \
    -quiet 2>&1 | tail -5

if [ ! -d "$RESULT_BUNDLE" ]; then
    echo "ERROR: Result bundle not created. Check build/test output above."
    exit 1
fi

echo ""
echo "Step 2: Extracting screenshots from result bundle..."

# Step 2: Extract attachments using xcresulttool
# List all test action attachments
ATTACHMENTS_JSON=$(xcrun xcresulttool get test-results attachments \
    --path "$RESULT_BUNDLE" \
    --format json 2>/dev/null || echo "[]")

if [ "$ATTACHMENTS_JSON" = "[]" ]; then
    echo "No attachments found. Falling back to manual extraction..."

    # Fallback: use xcresulttool to export attachments
    xcrun xcresulttool export \
        --type file \
        --path "$RESULT_BUNDLE" \
        --output-path "$HELP_IMAGES" 2>/dev/null || true

    # Look for PNG files in the result bundle directly
    find "$RESULT_BUNDLE" -name "*.png" -exec cp {} "$HELP_IMAGES/" \; 2>/dev/null || true
else
    echo "$ATTACHMENTS_JSON" | python3 -c "
import json, sys, subprocess, os

data = json.load(sys.stdin)
output_dir = '${HELP_IMAGES}'

for attachment in data:
    name = attachment.get('name', 'unknown')
    ref_id = attachment.get('payloadRef', {}).get('id', '')
    if not ref_id:
        continue

    filename = name.replace(' ', '-') + '.png'
    output_path = os.path.join(output_dir, filename)

    subprocess.run([
        'xcrun', 'xcresulttool', 'get',
        '--path', '${RESULT_BUNDLE}',
        '--id', ref_id,
        '--output-path', output_path
    ], check=True)
    print(f'  Extracted: {filename}')
"
fi

# Step 3: List extracted files
echo ""
echo "Step 3: Extracted screenshots:"
ls -la "$HELP_IMAGES"/*.png 2>/dev/null || echo "  (no PNG files found — see troubleshooting below)"

echo ""
echo "=== Done ==="
echo ""
echo "Screenshots are in:"
echo "  $HELP_IMAGES"
echo ""
echo "To rebuild the help index, run:"
echo "  bash Scripts/build-help-index.sh"
