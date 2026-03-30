import Foundation

enum YAMLValue: Equatable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: YAMLValue])
    case array([YAMLValue])
    case null
}

struct ParsedAgentDocument: Equatable, Sendable {
    let source: SourceFileReference
    let frontmatter: ParsedAgentFrontmatter?
    let rawFrontmatter: [String: YAMLValue]?
    let promptBody: String
}

struct ParsedAgentFrontmatter: Equatable, Sendable {
    let name: String?
    let description: String?
    let tools: [ParsedAgentToolEntry]
    let unknownFields: [String: YAMLValue]
}

struct ParsedAgentToolEntry: Equatable, Sendable {
    let rawValue: String
}

enum AgentFrontmatterParseState: Equatable, Sendable {
    case absent
    case parsed
    case malformed
}

struct AgentParser {
    private struct FrontmatterSplit {
        let frontmatter: String?
        let body: String
    }

    func parse(data: Data, sourceURL: URL) -> ParseResult<ParsedAgentDocument> {
        let source = SourceFileReference(url: sourceURL)
        let markdown = String(decoding: data, as: UTF8.self)
        var issues: [SyntaxIssue] = []

        let split = splitFrontmatter(markdown, sourcePath: source.displayPath, issues: &issues)

        guard let frontmatterText = split.frontmatter else {
            let document = ParsedAgentDocument(
                source: source,
                frontmatter: nil,
                rawFrontmatter: nil,
                promptBody: split.body
            )
            return ParseResult(value: document, issues: issues)
        }

        let parsedFrontmatter = parseFrontmatter(
            frontmatterText,
            sourcePath: source.displayPath,
            issues: &issues
        )

        let document = ParsedAgentDocument(
            source: source,
            frontmatter: parsedFrontmatter.typed,
            rawFrontmatter: parsedFrontmatter.raw,
            promptBody: split.body
        )

        return ParseResult(value: document, issues: issues)
    }

    func parse(markdownString: String, sourceURL: URL) -> ParseResult<ParsedAgentDocument> {
        parse(data: Data(markdownString.utf8), sourceURL: sourceURL)
    }

    private func splitFrontmatter(
        _ markdown: String,
        sourcePath: String,
        issues: inout [SyntaxIssue]
    ) -> FrontmatterSplit {
        guard isFrontmatterFenceOpening(markdown) else {
            return FrontmatterSplit(frontmatter: nil, body: markdown)
        }

        let firstLineEnd = indexAfterFirstLineBreak(in: markdown) ?? markdown.endIndex
        let contentStart = firstLineEnd
        var cursor = contentStart

        while cursor < markdown.endIndex {
            let lineStart = cursor
            let lineBreak = markdown[lineStart...].firstIndex(where: \.isNewline) ?? markdown.endIndex
            let lineText = markdown[lineStart..<lineBreak].trimmingCharacters(in: .whitespaces)

            let nextLineStart: String.Index
            if lineBreak < markdown.endIndex {
                var advanced = markdown.index(after: lineBreak)
                if markdown[lineBreak] == "\r", advanced < markdown.endIndex, markdown[advanced] == "\n" {
                    advanced = markdown.index(after: advanced)
                }
                nextLineStart = advanced
            } else {
                nextLineStart = markdown.endIndex
            }

            if lineText == "---" {
                let frontmatter = String(markdown[contentStart..<lineStart])
                let body = String(markdown[nextLineStart...])
                return FrontmatterSplit(frontmatter: frontmatter, body: body)
            }

            cursor = nextLineStart
        }

        issues.append(
            SyntaxIssue(
                code: .invalidFrontmatterFence,
                severity: .error,
                message: "Opening YAML frontmatter fence is missing a closing '---' fence.",
                sourcePath: sourcePath
            )
        )

        return FrontmatterSplit(frontmatter: nil, body: markdown)
    }

    private func parseFrontmatter(
        _ frontmatter: String,
        sourcePath: String,
        issues: inout [SyntaxIssue]
    ) -> (typed: ParsedAgentFrontmatter?, raw: [String: YAMLValue]?) {
        let parseResult = parseTopLevelMapping(frontmatter, sourcePath: sourcePath, issues: &issues)
        guard let rawObject = parseResult else {
            return (nil, nil)
        }

        var name: String?
        var description: String?
        var tools: [ParsedAgentToolEntry] = []
        var unknownFields = rawObject

        if let rawName = rawObject["name"] {
            name = parseRequiredString(
                rawName,
                keyPath: "name",
                sourcePath: sourcePath,
                issues: &issues
            )
            unknownFields.removeValue(forKey: "name")
        }

        if let rawDescription = rawObject["description"] {
            description = parseRequiredString(
                rawDescription,
                keyPath: "description",
                sourcePath: sourcePath,
                issues: &issues
            )
            unknownFields.removeValue(forKey: "description")
        }

        if let rawTools = rawObject["tools"] {
            tools = parseTools(rawTools, sourcePath: sourcePath, issues: &issues)
            unknownFields.removeValue(forKey: "tools")
        }

        let typed = ParsedAgentFrontmatter(
            name: name,
            description: description,
            tools: tools,
            unknownFields: unknownFields
        )

        return (typed, rawObject)
    }

    private func parseTopLevelMapping(
        _ text: String,
        sourcePath: String,
        issues: inout [SyntaxIssue]
    ) -> [String: YAMLValue]? {
        let lines = text
            .split(omittingEmptySubsequences: false, whereSeparator: { $0.isNewline })
            .map(String.init)
        var entries: [String: YAMLValue] = [:]
        var lineIndex = 0

        while lineIndex < lines.count {
            let rawLine = stripCarriageReturn(lines[lineIndex])
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                lineIndex += 1
                continue
            }

            let indent = indentationCount(for: rawLine)
            if indent != 0 {
                issues.append(
                    SyntaxIssue(
                        code: .invalidYAMLFrontmatter,
                        severity: .error,
                        message: "Malformed YAML frontmatter at line \(lineIndex + 1): expected top-level key.",
                        sourcePath: sourcePath
                    )
                )
                lineIndex += 1
                continue
            }

            if trimmed.hasPrefix("- ") || trimmed == "-" {
                issues.append(
                    SyntaxIssue(
                        code: .frontmatterTopLevelNotObject,
                        severity: .error,
                        message: "Agent frontmatter must be a YAML object with key-value pairs.",
                        sourcePath: sourcePath
                    )
                )
                return nil
            }

            guard let colonIndex = rawLine.firstIndex(of: ":") else {
                issues.append(
                    SyntaxIssue(
                        code: .invalidYAMLFrontmatter,
                        severity: .error,
                        message: "Malformed YAML frontmatter at line \(lineIndex + 1): expected 'key: value'.",
                        sourcePath: sourcePath
                    )
                )
                lineIndex += 1
                continue
            }

            let key = rawLine[..<colonIndex].trimmingCharacters(in: .whitespaces)
            if key.isEmpty {
                issues.append(
                    SyntaxIssue(
                        code: .invalidYAMLFrontmatter,
                        severity: .error,
                        message: "Malformed YAML frontmatter at line \(lineIndex + 1): empty key is not allowed.",
                        sourcePath: sourcePath
                    )
                )
                lineIndex += 1
                continue
            }

            let remainderStart = rawLine.index(after: colonIndex)
            let remainder = rawLine[remainderStart...].trimmingCharacters(in: .whitespaces)

            if !remainder.isEmpty {
                entries[key] = parseScalarValue(remainder)
                lineIndex += 1
                continue
            }

            var blockLines: [String] = []
            var blockIndex = lineIndex + 1
            while blockIndex < lines.count {
                let nextRawLine = stripCarriageReturn(lines[blockIndex])
                let nextTrimmed = nextRawLine.trimmingCharacters(in: .whitespaces)

                if nextTrimmed.isEmpty || nextTrimmed.hasPrefix("#") {
                    blockLines.append(nextRawLine)
                    blockIndex += 1
                    continue
                }

                if indentationCount(for: nextRawLine) == 0 {
                    break
                }

                blockLines.append(nextRawLine)
                blockIndex += 1
            }

            if blockLines.isEmpty {
                entries[key] = .null
                lineIndex = blockIndex
                continue
            }

            entries[key] = parseBlockValue(
                blockLines,
                parentKey: key,
                sourcePath: sourcePath,
                issues: &issues
            )
            lineIndex = blockIndex
        }

        return entries
    }

    private func parseBlockValue(
        _ lines: [String],
        parentKey: String,
        sourcePath: String,
        issues: inout [SyntaxIssue]
    ) -> YAMLValue {
        let meaningfulLines = lines.filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return !trimmed.isEmpty && !trimmed.hasPrefix("#")
        }

        guard let firstMeaningfulLine = meaningfulLines.first else {
            return .null
        }

        let firstTrimmed = firstMeaningfulLine.trimmingCharacters(in: .whitespaces)
        if firstTrimmed.hasPrefix("- ") || firstTrimmed == "-" {
            return parseBlockList(lines, keyPath: parentKey, sourcePath: sourcePath, issues: &issues)
        }

        return parseBlockObject(lines, keyPath: parentKey, sourcePath: sourcePath, issues: &issues)
    }

    private func parseBlockList(
        _ lines: [String],
        keyPath: String,
        sourcePath: String,
        issues: inout [SyntaxIssue]
    ) -> YAMLValue {
        var items: [YAMLValue] = []

        for rawLine in lines {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }

            guard trimmed.hasPrefix("- ") || trimmed == "-" else {
                issues.append(
                    SyntaxIssue(
                        code: .invalidYAMLFrontmatter,
                        severity: .error,
                        message: "Malformed list entry in frontmatter at '\(keyPath)'.",
                        sourcePath: sourcePath,
                        keyPath: keyPath
                    )
                )
                continue
            }

            let valueText = trimmed == "-" ? "" : String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            if valueText.isEmpty {
                items.append(.null)
            } else {
                items.append(parseScalarValue(valueText))
            }
        }

        return .array(items)
    }

    private func parseBlockObject(
        _ lines: [String],
        keyPath: String,
        sourcePath: String,
        issues: inout [SyntaxIssue]
    ) -> YAMLValue {
        var object: [String: YAMLValue] = [:]

        for rawLine in lines {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }

            guard let colonIndex = trimmed.firstIndex(of: ":") else {
                issues.append(
                    SyntaxIssue(
                        code: .invalidYAMLFrontmatter,
                        severity: .error,
                        message: "Malformed object entry in frontmatter at '\(keyPath)'.",
                        sourcePath: sourcePath,
                        keyPath: keyPath
                    )
                )
                continue
            }

            let key = trimmed[..<colonIndex].trimmingCharacters(in: .whitespaces)
            let remainderStart = trimmed.index(after: colonIndex)
            let remainder = trimmed[remainderStart...].trimmingCharacters(in: .whitespaces)

            if key.isEmpty {
                issues.append(
                    SyntaxIssue(
                        code: .invalidYAMLFrontmatter,
                        severity: .error,
                        message: "Malformed object entry in frontmatter at '\(keyPath)': empty key.",
                        sourcePath: sourcePath,
                        keyPath: keyPath
                    )
                )
                continue
            }

            object[key] = remainder.isEmpty ? .null : parseScalarValue(remainder)
        }

        return .object(object)
    }

    private func parseTools(
        _ value: YAMLValue,
        sourcePath: String,
        issues: inout [SyntaxIssue]
    ) -> [ParsedAgentToolEntry] {
        guard case let .array(rawArray) = value else {
            issues.append(
                SyntaxIssue(
                    code: .typeMismatch,
                    severity: .error,
                    message: "Expected array at tools.",
                    sourcePath: sourcePath,
                    keyPath: "tools"
                )
            )
            return []
        }

        var tools: [ParsedAgentToolEntry] = []

        for (index, item) in rawArray.enumerated() {
            guard case let .string(tool) = item else {
                issues.append(
                    SyntaxIssue(
                        code: .typeMismatch,
                        severity: .error,
                        message: "Expected string entry at tools[\(index)].",
                        sourcePath: sourcePath,
                        keyPath: "tools[\(index)]"
                    )
                )
                continue
            }
            tools.append(ParsedAgentToolEntry(rawValue: tool))
        }

        return tools
    }

    private func parseRequiredString(
        _ value: YAMLValue,
        keyPath: String,
        sourcePath: String,
        issues: inout [SyntaxIssue]
    ) -> String? {
        guard case let .string(stringValue) = value else {
            issues.append(
                SyntaxIssue(
                    code: .typeMismatch,
                    severity: .error,
                    message: "Expected string at \(keyPath).",
                    sourcePath: sourcePath,
                    keyPath: keyPath
                )
            )
            return nil
        }

        return stringValue
    }

    private func parseScalarValue(_ raw: String) -> YAMLValue {
        if let inlineArray = parseInlineArray(raw) {
            return .array(inlineArray)
        }

        if raw == "true" {
            return .bool(true)
        }
        if raw == "false" {
            return .bool(false)
        }
        if raw == "null" || raw == "~" {
            return .null
        }
        if let number = Double(raw) {
            return .number(number)
        }

        if (raw.hasPrefix("\"") && raw.hasSuffix("\"")) || (raw.hasPrefix("'") && raw.hasSuffix("'")) {
            return .string(String(raw.dropFirst().dropLast()))
        }

        return .string(raw)
    }

    private func parseInlineArray(_ raw: String) -> [YAMLValue]? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("["), trimmed.hasSuffix("]") else {
            return nil
        }

        let inner = String(trimmed.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
        if inner.isEmpty {
            return []
        }

        return inner
            .split(separator: ",", omittingEmptySubsequences: false)
            .map { parseScalarValue($0.trimmingCharacters(in: .whitespaces)) }
    }

    private func isFrontmatterFenceOpening(_ markdown: String) -> Bool {
        guard markdown.hasPrefix("---") else {
            return false
        }

        if markdown.count == 3 {
            return true
        }

        let fenceEnd = markdown.index(markdown.startIndex, offsetBy: 3)
        guard fenceEnd < markdown.endIndex else {
            return true
        }

        return markdown[fenceEnd].isNewline
    }

    private func indexAfterFirstLineBreak(in text: String) -> String.Index? {
        guard let lineBreak = text.firstIndex(where: \.isNewline) else {
            return nil
        }

        var index = text.index(after: lineBreak)
        if text[lineBreak] == "\r", index < text.endIndex, text[index] == "\n" {
            index = text.index(after: index)
        }
        return index
    }

    private func indentationCount(for line: String) -> Int {
        line.prefix(while: { $0 == " " }).count
    }

    private func stripCarriageReturn(_ line: String) -> String {
        line.hasSuffix("\r") ? String(line.dropLast()) : line
    }
}
