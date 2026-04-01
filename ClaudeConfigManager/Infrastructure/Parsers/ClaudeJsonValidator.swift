import Foundation

struct ClaudeJsonValidator {
    /// Validate a parsed ClaudeJsonDocument against expected types and keys.
    /// The six keys from Packet 06 are: autoConnectIde, autoInstallIdeExtension,
    /// editorMode, showTurnDuration, terminalProgressBarEnabled, and teammateMode.
    /// Returns an array of SyntaxIssues — does not throw.
    func validate(_ document: ParsedClaudeJsonDocument) -> [SyntaxIssue] {
        var issues: [SyntaxIssue] = []
        let sourcePath = document.source.displayPath

        // Known top-level keys for .claude.json (parser handles type validation)
        let knownClaudeJsonKeys: Set<String> = [
            "$schema",
            "schema",
            "autoConnectIde",
            "autoInstallIdeExtension",
            "editorMode",
            "showTurnDuration",
            "terminalProgressBarEnabled",
            "teammateMode",
            "globalPreferences",
            "mcp",
            "mcpState",
            "trust",
            "trustState"
        ]

        for key in document.rawTopLevelObject.keys {
            if !knownClaudeJsonKeys.contains(key) {
                issues.append(SyntaxIssue(
                    code: .unknownKey,
                    severity: .info,
                    message: "Unknown key '\(key)'",
                    sourcePath: sourcePath,
                    keyPath: key
                ))
            }
        }

        return issues
    }
}
