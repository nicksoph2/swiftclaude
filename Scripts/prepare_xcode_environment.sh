#!/bin/zsh

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
derived_data_root="${1:-/tmp/ClaudeConfigManagerDerivedData}"

echo "Repo root: $repo_root"
echo "DerivedData: $derived_data_root"

echo
echo "Clearing extended attributes that can break codesign..."
xattr -cr \
  "$repo_root/ClaudeConfigManager" \
  "$repo_root/ClaudeConfigManager.xcodeproj" \
  "$repo_root/ClaudeConfigManagerTests" \
  2>/dev/null || true

if [[ -d "$repo_root/.derivedData" ]]; then
  xattr -cr "$repo_root/.derivedData" 2>/dev/null || true
fi

echo
echo "Recommended Xcode setup:"
echo "1. Xcode > Settings > Locations > Derived Data"
echo "2. Use Default or a custom path outside synced folders"
echo "3. Avoid Derived Data inside iCloud/Dropbox/OneDrive-backed workspaces"

echo
echo "Smoke test build:"
xcodebuild \
  -project "$repo_root/ClaudeConfigManager.xcodeproj" \
  -scheme ClaudeConfigManager \
  -destination 'platform=macOS' \
  -derivedDataPath "$derived_data_root" \
  build
