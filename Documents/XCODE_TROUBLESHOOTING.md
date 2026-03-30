# Xcode Troubleshooting

## What failed
The app target can fail during `CodeSign` with:

- `resource fork, Finder information, or similar detritus not allowed`

This is not usually caused by the bundle identifier, team, or signing style.

## Root cause found here
This workspace lives under `Documents/...`, and local File Provider metadata was being attached to:

- `ClaudeConfigManager.xcodeproj`
- `ClaudeConfigManager/Resources/Assets.xcassets`
- the built `.app` bundle when Derived Data was written inside the workspace

That metadata causes `codesign` to reject the built app bundle.

## Confirmed working setup
The app builds successfully when:

1. extended attributes are cleared with `xattr -cr`
2. Derived Data is written outside the synced workspace

Example:

```bash
./Scripts/prepare_xcode_environment.sh
```

## Recommended settings on both machines

1. In Xcode, open `Settings > Locations`
2. Leave `Derived Data` on `Default`, or set it to a folder outside iCloud/Dropbox/OneDrive-managed paths
3. Do not use a repo-local Derived Data folder inside synced `Documents`

## Useful commands

Clear metadata from project files:

```bash
xattr -cr ClaudeConfigManager ClaudeConfigManager.xcodeproj ClaudeConfigManagerTests
```

Build with a safe Derived Data path:

```bash
xcodebuild -project ClaudeConfigManager.xcodeproj -scheme ClaudeConfigManager -destination 'platform=macOS' -derivedDataPath /tmp/ClaudeConfigManagerDerivedData build
```

Inspect suspicious metadata:

```bash
xattr -lr ClaudeConfigManager ClaudeConfigManager.xcodeproj ClaudeConfigManagerTests
xattr -lr .derivedData/Build/Products/Debug/ClaudeConfigManager.app
```

## Known non-project issue in this environment
Hosted tests can still fail here because the sandbox blocks communication with `testmanagerd`. That is separate from the code-signing problem.
