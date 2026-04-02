#!/bin/bash
# Build the Apple Help Book search index.
# Run from the project root:
#   bash ClaudeConfigManager/Resources/ClaudeConfigManager.help/Contents/Resources/en.lproj/pages/helpindex-build.sh
#
# Requires Xcode command-line tools (hiutil is included with macOS).

set -euo pipefail

HELP_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
INDEX_PATH="${HELP_DIR}/ClaudeConfigManager.helpindex"

echo "Building help index at: ${INDEX_PATH}"
hiutil -Caf "$INDEX_PATH" "${HELP_DIR}/en.lproj"
echo "Done. Index size: $(du -h "$INDEX_PATH" | cut -f1)"
