import Foundation

struct ParsedSkillDocument: Equatable, Sendable {
    let directory: SkillDirectoryMetadata
    let frontmatter: ParsedSkillFrontmatter?
    let rawFrontmatter: [String: YAMLValue]?
    let body: String?
    let supportingReferences: [ParsedSkillSupportingReference]
}

struct SkillDirectoryMetadata: Equatable, Sendable {
    let skillRootURL: URL
    let skillMarkdownURL: URL
    let hasSkillMarkdown: Bool
}

struct ParsedSkillFrontmatter: Equatable, Sendable {
    let name: String?
    let description: String?
    let version: String?
    let tags: [String]?
    let unknownFields: [String: YAMLValue]
}

enum ParsedSkillReferenceKind: String, Equatable, Sendable {
    case link
    case image
}

struct ParsedSkillSupportingReference: Equatable, Sendable {
    let originalToken: String
    let normalizedPath: String?
    let kind: ParsedSkillReferenceKind
    let isParseableLocalFileReference: Bool
}

struct SkillParser {
    private struct FrontmatterSplit {
        let frontmatter: String?
        let body: String
    }

    func parse(skillDirectoryURL: URL, skillMarkdownData: Data?) -> ParseResult<ParsedSkillDocument> {
        let skillMarkdownURL = skillDirectoryURL.appendingPathComponent("SKILL.md", isDirectory: false)
        var issues: [SyntaxIssue] = []

        let metadata = SkillDirectoryMetadata(
            skillRootURL: skillDirectoryURL,
            skillMarkdownURL: skillMarkdownURL,
            hasSkillMarkdown: skillMarkdownData != nil
        )

        guard let skillMarkdownData else {
            issues.append(
                SyntaxIssue(
                    code: .missingSkillMarkdown,
                    severity: .error,
                    message: "Skill directory is missing SKILL.md.",
                    sourcePath: skillMarkdownURL.path
                )
            )

            let document = ParsedSkillDocument(
                directory: metadata,
                frontmatter: nil,
                rawFrontmatter: nil,
                body: nil,
                supportingReferences: []
            )
            return ParseResult(value: document, issues: issues)
        }

        let markdown = String(decoding: skillMarkdownData, as: UTF8.self)
        let split = splitFrontmatter(markdown, sourcePath: skillMarkdownURL.path, issues: &issues)
        let parsedFrontmatter: (typed: ParsedSkillFrontmatter?, raw: [String: YAMLValue]?)

        if let frontmatterText = split.frontmatter {
            parsedFrontmatter = parseFrontmatter(frontmatterText, sourcePath: skillMarkdownURL.path, issues: &issues)
        } else {
            parsedFrontmatter = (nil, nil)
        }

        let references = extractSupportingReferences(from: split.body, sourcePath: skillMarkdownURL.path, issues: &issues)

        let document = ParsedSkillDocument(
            directory: metadata,
            frontmatter: parsedFrontmatter.typed,
            rawFrontmatter: parsedFrontmatter.raw,
            body: split.body,
            supportingReferences: references
        )

        return ParseResult(value: document, issues: issues)
    }

    func parse(skillDirectoryURL: URL, markdownString: String) -> ParseResult<ParsedSkillDocument> {
        parse(skillDirectoryURL: skillDirectoryURL, skillMarkdownData: Data(markdownString.utf8))
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
    ) -> (typed: ParsedSkillFrontmatter?, raw: [String: YAMLValue]?) {
        guard let rawObject = parseTopLevelMapping(frontmatter, sourcePath: sourcePath, issues: &issues) else {
            return (nil, nil)
        }

        var name: String?
        var description: String?
        var version: String?
        var tags: [String]?
        var unknownFields = rawObject

        if let rawName = rawObject["name"] {
            name = parseRequiredString(rawName, keyPath: "name", sourcePath: sourcePath, issues: &issues)
            unknownFields.removeValue(forKey: "name")
        }

        if let rawDescription = rawObject["description"] {
            description = parseRequiredString(rawDescription, keyPath: "description", sourcePath: sourcePath, issues: &issues)
            unknownFields.removeValue(forKey: "description")
        }

        if let rawVersion = rawObject["version"] {
            version = parseRequiredString(rawVersion, keyPath: "version", sourcePath: sourcePath, issues: &issues)
            unknownFields.removeValue(forKey: "version")
        }

        if let rawTags = rawObject["tags"] {
            tags = parseStringArray(rawTags, keyPath: "tags", sourcePath: sourcePath, issues: &issues)
            unknownFields.removeValue(forKey: "tags")
        }

        let typed = ParsedSkillFrontmatter(
            name: name,
            description: description,
            version: version,
            tags: tags,
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
                        message: "Skill frontmatter must be a YAML object with key-value pairs.",
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

    private func parseStringArray(
        _ value: YAMLValue,
        keyPath: String,
        sourcePath: String,
        issues: inout [SyntaxIssue]
    ) -> [String]? {
        guard case let .array(items) = value else {
            issues.append(
                SyntaxIssue(
                    code: .typeMismatch,
                    severity: .error,
                    message: "Expected array at \(keyPath).",
                    sourcePath: sourcePath,
                    keyPath: keyPath
                )
            )
            return nil
        }

        var values: [String] = []
        for (index, item) in items.enumerated() {
            guard case let .string(stringValue) = item else {
                issues.append(
                    SyntaxIssue(
                        code: .typeMismatch,
                        severity: .error,
                        message: "Expected string entry at \(keyPath)[\(index)].",
                        sourcePath: sourcePath,
                        keyPath: "\(keyPath)[\(index)]"
                    )
                )
                continue
            }
            values.append(stringValue)
        }

        return values
    }

    private func extractSupportingReferences(
        from markdownBody: String,
        sourcePath: String,
        issues: inout [SyntaxIssue]
    ) -> [ParsedSkillSupportingReference] {
        var references: [ParsedSkillSupportingReference] = []
        var cursor = markdownBody.startIndex

        while cursor < markdownBody.endIndex {
            let character = markdownBody[cursor]
            if character != "[" && character != "!" {
                cursor = markdownBody.index(after: cursor)
                continue
            }

            if character == "[" {
                if cursor > markdownBody.startIndex {
                    let previous = markdownBody[markdownBody.index(before: cursor)]
                    if previous == "!" {
                        cursor = markdownBody.index(after: cursor)
                        continue
                    }
                }
            } else {
                let bracketIndex = markdownBody.index(after: cursor)
                guard bracketIndex < markdownBody.endIndex, markdownBody[bracketIndex] == "[" else {
                    cursor = markdownBody.index(after: cursor)
                    continue
                }
            }

            let parseResult = parseReferenceToken(in: markdownBody, from: cursor)
            switch parseResult {
            case let .valid(tokenRange, pathText, kind):
                let tokenText = String(markdownBody[tokenRange])
                let normalizedPath = normalizePath(pathText)
                let reference = ParsedSkillSupportingReference(
                    originalToken: tokenText,
                    normalizedPath: normalizedPath,
                    kind: kind,
                    isParseableLocalFileReference: isParseableLocalFileReference(normalizedPath)
                )
                references.append(reference)
                cursor = tokenRange.upperBound

            case let .malformed(problemIndex, recoveryIndex):
                let location = lineAndColumn(for: problemIndex, in: markdownBody)
                issues.append(
                    SyntaxIssue(
                        code: .invalidMarkdownReferenceToken,
                        severity: .error,
                        message: "Malformed markdown reference token.",
                        sourcePath: sourcePath,
                        range: SourceRange(
                            startLine: location.line,
                            startColumn: location.column,
                            endLine: location.line,
                            endColumn: location.column
                        )
                    )
                )
                cursor = recoveryIndex > cursor ? recoveryIndex : markdownBody.index(after: cursor)

            case let .notReference(nextCursor):
                cursor = nextCursor
            }
        }

        return references
    }

    private enum ReferenceTokenParseResult {
        case valid(Range<String.Index>, String, ParsedSkillReferenceKind)
        case malformed(problemIndex: String.Index, recoveryIndex: String.Index)
        case notReference(nextCursor: String.Index)
    }

    private func parseReferenceToken(in text: String, from start: String.Index) -> ReferenceTokenParseResult {
        let isImage: Bool
        let openingBracketIndex: String.Index

        if text[start] == "!" {
            let bracketIndex = text.index(after: start)
            guard bracketIndex < text.endIndex, text[bracketIndex] == "[" else {
                return .notReference(nextCursor: text.index(after: start))
            }
            isImage = true
            openingBracketIndex = bracketIndex
        } else {
            isImage = false
            openingBracketIndex = start
        }

        let linkTextClose = text[openingBracketIndex...].firstIndex(of: "]")
        guard let linkTextClose else {
            return .malformed(problemIndex: openingBracketIndex, recoveryIndex: endOfCurrentLine(from: openingBracketIndex, in: text))
        }

        let openParen = text.index(after: linkTextClose)
        guard openParen < text.endIndex, text[openParen] == "(" else {
            return .notReference(nextCursor: text.index(after: openingBracketIndex))
        }

        guard let closeParen = text[openParen...].firstIndex(of: ")") else {
            return .malformed(problemIndex: openParen, recoveryIndex: endOfCurrentLine(from: openParen, in: text))
        }

        let pathStart = text.index(after: openParen)
        let pathText = String(text[pathStart..<closeParen])
        let tokenStart = isImage ? start : openingBracketIndex
        let tokenRange = tokenStart..<text.index(after: closeParen)

        let kind: ParsedSkillReferenceKind = isImage ? .image : .link
        return .valid(tokenRange, pathText, kind)
    }

    private func normalizePath(_ rawPath: String) -> String? {
        var value = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("<"), value.hasSuffix(">"), value.count >= 2 {
            value = String(value.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return value.isEmpty ? nil : value
    }

    private func isParseableLocalFileReference(_ normalizedPath: String?) -> Bool {
        guard let normalizedPath else {
            return false
        }

        if normalizedPath.hasPrefix("#") {
            return false
        }

        if normalizedPath.contains("://") {
            return false
        }

        return true
    }

    private func lineAndColumn(for index: String.Index, in text: String) -> (line: Int, column: Int) {
        var line = 1
        var column = 1
        var cursor = text.startIndex

        while cursor < index {
            if text[cursor].isNewline {
                line += 1
                column = 1
            } else {
                column += 1
            }
            cursor = text.index(after: cursor)
        }

        return (line, column)
    }

    private func endOfCurrentLine(from index: String.Index, in text: String) -> String.Index {
        text[index...].firstIndex(where: \.isNewline) ?? text.endIndex
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
