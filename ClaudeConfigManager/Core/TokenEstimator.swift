import Foundation

/// Provides a rough token-count estimate for arbitrary text.
///
/// Uses the simple heuristic of ~4 UTF-8 bytes per token, which is a
/// reasonable average for English text with the Claude tokenizer.
/// Results should be labeled "approximate" in the UI.
enum TokenEstimator {

    /// Returns an approximate token count for the given text.
    /// Always returns at least 1 for non-empty strings.
    static func estimateTokenCount(_ text: String) -> Int {
        guard !text.isEmpty else { return 0 }
        return max(1, text.utf8.count / 4)
    }
}
