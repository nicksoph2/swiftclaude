import XCTest

/// UI test suite that captures screenshots of every major view for the Help Book.
///
/// Run via Xcode MCP or:
///   xcodebuild test \
///     -project ClaudeConfigManager/ClaudeConfigManager.xcodeproj \
///     -scheme ClaudeConfigManager \
///     -destination 'platform=macOS' \
///     -only-testing:ClaudeConfigManagerUITests/ScreenshotCaptureTests \
///     -resultBundlePath ./ScreenshotResults
final class ScreenshotCaptureTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments += [
            "-hasSeenIntro", "YES",
            "-skipInitialGlobalRootSetup", "YES",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US"
        ]
        app.launch()

        // Wait for the main window
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 10), "App window should appear")

        // Dismiss any modal sheets that may appear (auth sheet, intro, etc.)
        dismissAnySheets()
    }

    override func tearDownWithError() throws {
        if let app = app {
            app.terminate()
        }
        app = nil
    }

    // MARK: - Helpers

    /// Dismiss modal sheets by looking for known dismiss buttons.
    private func dismissAnySheets() {
        // Try dismissing the initial global root auth sheet
        let skipButton = app.buttons["Skip for Now"]
        if skipButton.waitForExistence(timeout: 3) {
            skipButton.click()
            usleep(500_000)
        }

        // Try dismissing the intro animation if it appears despite the launch arg
        let dismissButton = app.buttons["Dismiss"]
        if dismissButton.waitForExistence(timeout: 1) {
            dismissButton.click()
            usleep(500_000)
        }

        // Also try Close / Done buttons
        for label in ["Close", "Done", "OK", "Got It"] {
            let btn = app.buttons[label]
            if btn.exists {
                btn.click()
                usleep(300_000)
            }
        }
    }

    private func captureScreenshot(named name: String) {
        // Capture the full window
        let screenshot = app.windows.firstMatch.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func navigateToSidebar(_ itemTitle: String) {
        // Try outline first (NavigationSplitView sidebar)
        let sidebar = app.outlines.firstMatch
        if sidebar.waitForExistence(timeout: 3) {
            let row = sidebar.staticTexts[itemTitle]
            if row.waitForExistence(timeout: 3) {
                row.click()
                usleep(800_000) // 0.8s for detail view to load
                return
            }
        }

        // Fallback: try lists
        let list = app.tables.firstMatch
        if list.waitForExistence(timeout: 2) {
            let cell = list.staticTexts[itemTitle]
            if cell.waitForExistence(timeout: 2) {
                cell.click()
                usleep(800_000)
                return
            }
        }

        // Last resort: search all static texts
        let text = app.staticTexts[itemTitle]
        if text.waitForExistence(timeout: 2) {
            text.click()
            usleep(800_000)
        }
    }

    // MARK: - Dashboard

    func testCaptureDashboard() throws {
        navigateToSidebar("Dashboard")
        captureScreenshot(named: "01-dashboard")
    }

    // MARK: - Scope Views

    func testCaptureManagedScope() throws {
        navigateToSidebar("Managed")
        captureScreenshot(named: "02-scope-managed")
    }

    func testCaptureUserScope() throws {
        navigateToSidebar("User")
        captureScreenshot(named: "03-scope-user")
    }

    func testCaptureProjectScope() throws {
        navigateToSidebar("Project")
        captureScreenshot(named: "04-scope-project")
    }

    func testCaptureProjectLocalScope() throws {
        navigateToSidebar("Project-Local")
        captureScreenshot(named: "05-scope-project-local")
    }

    func testCaptureSessionScope() throws {
        navigateToSidebar("Session")
        captureScreenshot(named: "06-scope-session")
    }

    func testCaptureCLIScope() throws {
        navigateToSidebar("CLI")
        captureScreenshot(named: "07-scope-cli")
    }

    // MARK: - Output & Views

    func testCaptureResolvedConfig() throws {
        navigateToSidebar("Resolved Config")
        captureScreenshot(named: "08-resolved-config")
    }

    func testCapturePipelineView() throws {
        navigateToSidebar("Pipeline View")
        usleep(1_500_000) // 1.5s for animations
        captureScreenshot(named: "09-pipeline-view")
    }

    func testCapturePermissionsInspector() throws {
        navigateToSidebar("Permissions")
        captureScreenshot(named: "10-permissions-inspector")
    }

    func testCaptureIssuesView() throws {
        navigateToSidebar("Issues")
        captureScreenshot(named: "11-issues")
    }

    func testCaptureTranscripts() throws {
        navigateToSidebar("Transcripts")
        captureScreenshot(named: "12-transcripts")
    }

    func testCaptureUsageAnalytics() throws {
        navigateToSidebar("Usage Analytics")
        captureScreenshot(named: "13-usage-analytics")
    }

    // MARK: - Overlays

    func testCaptureGlobalSearch() throws {
        app.typeKey("f", modifierFlags: .command)
        usleep(800_000)
        captureScreenshot(named: "14-global-search")
        app.typeKey(.escape, modifierFlags: [])
    }

    func testCaptureHelpSearch() throws {
        app.typeKey("/", modifierFlags: [.command, .shift])
        usleep(800_000)
        captureScreenshot(named: "15-help-search")
        app.typeKey(.escape, modifierFlags: [])
    }
}
