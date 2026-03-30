import XCTest
@testable import ClaudeConfigManager

final class ClaudeConfigManagerTests: XCTestCase {
    func testSidebarDestinationsExposeExpectedOrder() {
        XCTAssertEqual(
            SidebarDestination.allCases,
            [.managed, .user, .project, .session]
        )
    }

    func testScopeScreenModelUsesSidebarCopy() {
        let model = ScopeScreenModel(destination: .session)

        XCTAssertEqual(model.title, "Session")
        XCTAssertTrue(model.subtitle.contains("read-only"))
    }
}
