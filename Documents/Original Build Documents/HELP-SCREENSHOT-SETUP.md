# Help Book Screenshot Automation — Setup Guide

This document explains how to set up automated screenshot capture for the Claude Config Manager Help Book using XCTest UI tests.

## Overview

The project includes a UI test suite (`ScreenshotCaptureTests`) that launches the app, navigates to every major view, and captures screenshots as test attachments. A companion script extracts those screenshots and places them in the Help Book's image directory.

## Prerequisites

1. **Xcode 16+** with command-line tools installed
2. **XcodeGen** installed (`brew install xcodegen`)
3. **macOS 15.0+** (the app's deployment target)
4. **Accessibility permissions** for Xcode Helper (required for UI testing)

## One-Time Setup

### 1. Grant Accessibility Permissions

UI tests need to control the app via the Accessibility API. macOS will prompt you the first time, but you can also set it up in advance:

1. Open **System Settings → Privacy & Security → Accessibility**
2. Click the **+** button
3. Add `/Applications/Xcode.app` (or your Xcode installation path)
4. Also add **Xcode Helper** if it appears separately

Without this, UI tests will fail with "not permitted to send keystrokes".

### 2. Regenerate the Xcode Project

The UI test target was added to `project.yml`. Regenerate:

```bash
cd ClaudeConfigManager
xcodegen generate
```

### 3. Build the App Once

Make sure the app builds before running screenshot tests:

```bash
xcodebuild build \
    -project ClaudeConfigManager.xcodeproj \
    -scheme ClaudeConfigManager \
    -destination 'platform=macOS' \
    -quiet
```

## Capturing Screenshots

### Option A: Run the Script (Recommended)

```bash
bash Scripts/capture-screenshots.sh
```

This runs the UI tests, extracts all screenshot attachments, and places them in:
```
ClaudeConfigManager/Resources/ClaudeConfigManager.help/Contents/Resources/en.lproj/images/
```

### Option B: Run from Xcode

1. Open the project in Xcode
2. Select the **ClaudeConfigManager** scheme
3. Navigate to **ClaudeConfigManagerUITests → ScreenshotCaptureTests**
4. Run all tests in the class (⌘U or right-click → Run)
5. After tests pass, open the **Report Navigator** (⌘9)
6. Click the test run → expand each test → click the screenshot attachment to preview
7. Right-click any attachment → **Export** to save as PNG

### Option C: Run from Claude Code

If you're using Claude Code and want Claude to capture screenshots automatically:

```bash
# Run the screenshot tests
xcodebuild test \
    -project ClaudeConfigManager.xcodeproj \
    -scheme ClaudeConfigManager \
    -destination 'platform=macOS' \
    -only-testing:ClaudeConfigManagerUITests/ScreenshotCaptureTests \
    -resultBundlePath ./ScreenshotResults.xcresult \
    -quiet

# Extract screenshots
bash Scripts/capture-screenshots.sh
```

**Important for Claude Code:** Claude Code runs in a sandboxed terminal. For UI tests to work, the terminal process must have Accessibility permissions. If you're running Claude Code from Terminal.app or iTerm, add that terminal app to the Accessibility list in System Settings.

## Screenshot Inventory

The test suite captures these screenshots:

| Test Method | Output Filename | View |
|---|---|---|
| `testCaptureDashboard` | `01-dashboard.png` | Dashboard overview |
| `testCaptureManagedScope` | `02-scope-managed.png` | Managed scope |
| `testCaptureUserScope` | `03-scope-user.png` | User scope |
| `testCaptureProjectScope` | `04-scope-project.png` | Project scope |
| `testCaptureProjectLocalScope` | `05-scope-project-local.png` | Project-Local scope |
| `testCaptureSessionScope` | `06-scope-session.png` | Session scope |
| `testCaptureCLIScope` | `07-scope-cli.png` | CLI scope |
| `testCaptureResolvedConfig` | `08-resolved-config.png` | Resolved Config |
| `testCapturePipelineView` | `09-pipeline-view.png` | Pipeline View |
| `testCapturePermissionsInspector` | `10-permissions-inspector.png` | Permissions Inspector |
| `testCaptureIssuesView` | `11-issues.png` | Issues |
| `testCaptureTranscripts` | `12-transcripts.png` | Transcripts |
| `testCaptureUsageAnalytics` | `13-usage-analytics.png` | Usage Analytics |
| `testCaptureGlobalSearch` | `14-global-search.png` | Global Search overlay |
| `testCaptureHelpSearch` | `15-help-search.png` | Help Search overlay |

## After Capturing

Once screenshots are in the images directory, the Help Book HTML pages will reference them. To update the page references, replace the `screenshot-placeholder` divs in the HTML files with `<img>` tags:

```html
<!-- Replace this: -->
<div class="screenshot-placeholder">Screenshot: Dashboard overview</div>

<!-- With this: -->
<img src="../images/01-dashboard.png" alt="Dashboard overview" class="screenshot">
```

Then rebuild the help search index:

```bash
bash Scripts/build-help-index.sh
```

## Troubleshooting

**"Not permitted to send keystrokes"** — Add Xcode and your terminal to Accessibility permissions.

**UI tests fail to find sidebar items** — The app may show the intro animation or folder authorisation sheet on first launch. The test suite passes `-hasSeenIntro YES` to suppress the intro, but if your User Defaults have been reset, the authorisation sheet may block navigation. Dismiss it manually once, or add a launch argument to skip it.

**No screenshots in result bundle** — Ensure the tests actually passed (or at least ran). Check the Xcode test report for failures. Screenshots are only captured when the `captureScreenshot` call executes.

**Script can't find xcresulttool** — Make sure Xcode command-line tools are selected: `xcode-select -p` should point to your Xcode.
