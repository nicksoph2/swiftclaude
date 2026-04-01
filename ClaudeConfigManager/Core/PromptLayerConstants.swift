import Foundation

/// Token-budget constants for the prompt assembly and context budget stages.
///
/// These values are approximate midpoints derived from the Claude Code
/// documentation and are used for the "estimated overhead" calculations
/// in the Tree view.
enum PromptLayerConstants {

    /// Approximate tokens consumed by the system prompt.
    static let systemPromptTokens: Int = 2_500

    /// Approximate tokens consumed by built-in + MCP tool definitions
    /// (midpoint of the documented 14K–17K range).
    static let toolDefinitionTokens: Int = 15_500

    /// Approximate baseline overhead (framing, safety layers, etc.)
    /// before any user-configurable content is injected.
    static let baselineOverhead: Int = 8_700

    /// Total context window size for Claude models (200K tokens).
    static let contextWindowSize: Int = 200_000
}
