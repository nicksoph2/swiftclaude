#!/bin/bash
# Build the Apple Help Book search index.
# Run from the project root:
#   bash Scripts/build-help-index.sh
#
# Requires Xcode command-line tools (hiutil is included with macOS).

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HELP_DIR="${PROJECT_ROOT}/ClaudeConfigManager/Resources/ClaudeConfigManager.help/Contents/Resources"
INDEX_PATH="${HELP_DIR}/ClaudeConfigManager.helpindex"

echo "=== Building Help Book Search Index ==="
echo "Source: ${HELP_DIR}/en.lproj"
echo "Output: ${INDEX_PATH}"
echo ""

hiutil -Caf "$INDEX_PATH" "${HELP_DIR}/en.lproj"

echo ""
echo "Done. Index size: $(du -h "$INDEX_PATH" | cut -f1)"
