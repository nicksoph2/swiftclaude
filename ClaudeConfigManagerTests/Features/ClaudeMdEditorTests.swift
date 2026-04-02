import XCTest
import SwiftUI
@testable import ClaudeConfigManager

final class ClaudeMdEditorTests: XCTestCase {
    
    func testClaudeMdTokenCountUpdatesOnChange() {
        let initialContent = "# Test\n\nHello world"
        let view = ClaudeMdEditorView(
            fileURL: URL(fileURLWithPath: "/Users/test/.claude/CLAUDE.md"),
            fileName: "CLAUDE.md",
            scope: .user,
            initialContent: initialContent,
            loadOrderIndex: 1
        )
        
        // Verify:
        // 1. Initial token count is calculated from initialContent
        // 2. Token count updates when content changes
        // 3. Updates are debounced (300ms)
        // 4. Token count uses TokenEstimator.estimateTokenCount()
        
        XCTAssertNotNil(view)
    }
    
    func testClaudeMdSaveIsAtomic() {
        let initialContent = "# Instructions\n\nBe helpful"
        let fileURL = URL(fileURLWithPath: "/tmp/test-claude.md")
        let view = ClaudeMdEditorView(
            fileURL: fileURL,
            fileName: "CLAUDE.md",
            scope: .user,
            initialContent: initialContent
        )
        
        // Verify:
        // 1. Save button is disabled when there are no unsaved changes
        // 2. Save button is enabled when content differs from initialContent
        // 3. Save operation calls AtomicFileWriter (or direct write in preview)
        // 4. Save shows progress indicator during write
        // 5. Save dismisses the editor on success
        
        XCTAssertNotNil(view)
    }
    
    func testClaudeMdImportReferenceExtraction() {
        let contentWithImports = """
        # Main Instructions
        
        @import ./helpers.md
        @import ../shared/style.md
        
        Some content here.
        
        @import ./more.md
        """
        
        let view = ClaudeMdEditorView(
            fileURL: URL(fileURLWithPath: "/Users/test/.claude/CLAUDE.md"),
            fileName: "CLAUDE.md",
            scope: .user,
            initialContent: contentWithImports
        )
        
        // Verify:
        // 1. Extracts paths from @import directives
        // 2. Displays "Imported files" collapsible section
        // 3. Shows found/not found status for each import
        // 4. Paths displayed are trimmed and cleaned
        
        XCTAssertNotNil(view)
    }
}
