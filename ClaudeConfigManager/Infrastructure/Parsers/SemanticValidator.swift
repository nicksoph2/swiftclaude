import Foundation

/// Semantic validator runs checks that require understanding multiple keys or scopes together.
/// Complements schema validation by catching cross-key and cross-scope configuration issues.
/// Named SemanticProjectionValidator to avoid conflict with the rule-based SemanticValidator in ResolverModels.
struct SemanticProjectionValidator {

    /// Run semantic checks against the fully-resolved SessionProjection.
    /// Returns validation issues that cannot be detected by per-file schema validation alone.
    func validate(_ projection: SessionProjection) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []

        // Check deny rule shadows allow rule
        issues.append(contentsOf: checkDenyRuleShadowsAllow(projection))

        // Check instruction token budget
        issues.append(contentsOf: checkInstructionTokenBudget(projection))

        // Check instruction @import cycles
        issues.append(contentsOf: checkInstructionImportCycles(projection))

        // Check redundant permission rules
        issues.append(contentsOf: checkRedundantPermissionRules(projection))

        // Check MCP servers referenced but not configured
        issues.append(contentsOf: checkMissingMcpServerReferences(projection))

        // Check sandbox blocks required tool
        issues.append(contentsOf: checkSandboxBlocksRequiredTool(projection))

        return issues.sorted { $0.id < $1.id }
    }

    // MARK: - Individual Validators

    private func checkDenyRuleShadowsAllow(_ projection: SessionProjection) -> [ValidationIssue] {
        guard let settings = projection.settings else { return [] }

        var issues: [ValidationIssue] = []

        // Get all deny and allow rules from the resolved settings
        let denyRules = extractPermissionRules(settings, ruleType: "deny")
        let allowRules = extractPermissionRules(settings, ruleType: "allow")

        // For each deny rule, check if any allow rule would match the same tool
        for denyRule in denyRules {
            for allowRule in allowRules {
                if ruleMatches(denyRule: denyRule, allowRule: allowRule) {
                    let source = findPermissionRuleSource(settings, rule: denyRule)
                    let allowSource = findPermissionRuleSource(settings, rule: allowRule)

                    issues.append(
                        ValidationIssue(
                            code: .semantic("permissions.denyRuleShadowsAllow"),
                            severity: .warning,
                            category: .semantic,
                            message: "Deny rule '\(denyRule)' would be shadowed by allow rule '\(allowRule)'. Remove redundant rules or clarify intent.",
                            source: source,
                            keyPath: "permissions.deny",
                            relatedSources: allowSource.map { [$0] } ?? []
                        )
                    )
                }
            }
        }

        return issues
    }

    private func checkInstructionImportCycles(_ projection: SessionProjection) -> [ValidationIssue] {
        guard let instructions = projection.instructions else { return [] }

        let cycleEdges = instructions.importEdges.filter { $0.isCycle }
        guard !cycleEdges.isEmpty else { return [] }

        // Build a human-readable cycle path for each cycle edge.
        // Each cycle edge records the parent that tried to (re-)import an ancestor.
        let blockNameByID: [String: String] = Dictionary(
            uniqueKeysWithValues: instructions.orderedBlocks.map { block in
                let name: String
                if let path = block.content.winningSource?.sourcePath {
                    name = URL(fileURLWithPath: path).lastPathComponent
                } else {
                    name = block.content.winningSource?.displayName ?? block.blockID
                }
                return (block.blockID, name)
            }
        )

        var issues: [ValidationIssue] = []

        for edge in cycleEdges {
            let parentName = blockNameByID[edge.parentBlockID] ?? edge.parentBlockID
            let cyclePath = [parentName, edge.rawToken, parentName]
            let cyclePathString = cyclePath.joined(separator: " → ")

            let source = instructions.orderedBlocks
                .first(where: { $0.blockID == edge.parentBlockID })
                .flatMap { $0.content.winningSource }
                .map { ValidationSourceReference(resolutionSource: $0) }

            issues.append(
                ValidationIssue(
                    code: .semantic("instructions.importCycle"),
                    severity: .error,
                    category: .semantic,
                    message: "Import cycle detected: \(cyclePathString) (cycle). The cycling file will not be loaded; its instructions are missing from Claude's context.",
                    source: source,
                    keyPath: "instructions",
                    relatedSources: []
                )
            )
        }

        return issues
    }

    private func checkInstructionTokenBudget(_ projection: SessionProjection) -> [ValidationIssue] {
        guard let instructions = projection.instructions else { return [] }

        var totalTokens = 0
        let threshold = 50_000  // 25% of 200,000 token context window

        // Sum tokens from all instruction blocks
        for block in instructions.orderedBlocks {
            let blockTokens = TokenEstimator.estimateTokenCount(block.content.effectiveValue ?? "")
            totalTokens += blockTokens
        }

        guard totalTokens >= threshold else { return [] }

        return [
            ValidationIssue(
                code: .semantic("instructions.tokenBudgetExceeded"),
                severity: .warning,
                category: .semantic,
                message: "Total instruction content tokens (\(totalTokens)) exceeds recommended threshold (\(threshold)). This may consume excessive context.",
                source: instructions.orderedBlocks.first.map { block in
                    ValidationSourceReference(virtualIdentifier: "instructions", displayName: "Composed Instructions")
                },
                keyPath: nil,
                relatedSources: []
            )
        ]
    }

    private func checkRedundantPermissionRules(_ projection: SessionProjection) -> [ValidationIssue] {
        guard let settings = projection.settings else { return [] }

        var issues: [ValidationIssue] = []

        // Check each scope's rules for duplicates
        for entry in settings.entries {
            guard entry.keyPath == "permissions" else { continue }

            guard let permissionsValue = entry.value.effectiveValue,
                  case .object(let permissionsObj) = permissionsValue else {
                continue
            }

            // Check deny rules
            if let denyRules = permissionsObj["deny"], case .array(let denyArray) = denyRules {
                let duplicates = findDuplicateStrings(denyArray)
                for (rule, count) in duplicates {
                    issues.append(
                        ValidationIssue(
                            code: .semantic("permissions.redundantDenyRule"),
                            severity: .info,
                            category: .semantic,
                            message: "Deny rule '\(rule)' appears \(count) times in the same scope. Remove duplicate rules.",
                            source: entry.value.winningSource.map(ValidationSourceReference.init(resolutionSource:)),
                            keyPath: "permissions.deny",
                            relatedSources: []
                        )
                    )
                }
            }

            // Check allow rules
            if let allowRules = permissionsObj["allow"], case .array(let allowArray) = allowRules {
                let duplicates = findDuplicateStrings(allowArray)
                for (rule, count) in duplicates {
                    issues.append(
                        ValidationIssue(
                            code: .semantic("permissions.redundantAllowRule"),
                            severity: .info,
                            category: .semantic,
                            message: "Allow rule '\(rule)' appears \(count) times in the same scope. Remove duplicate rules.",
                            source: entry.value.winningSource.map(ValidationSourceReference.init(resolutionSource:)),
                            keyPath: "permissions.allow",
                            relatedSources: []
                        )
                    )
                }
            }
        }

        return issues
    }

    private func checkMissingMcpServerReferences(_ projection: SessionProjection) -> [ValidationIssue] {
        guard let hooks = projection.hooks else { return [] }
        guard let mcpServers = projection.mcp else { return [] }

        var issues: [ValidationIssue] = []

        // Build a set of configured MCP server IDs
        let configuredServerIDs = Set(mcpServers.servers.map { $0.serverID })

        // Check each hook handler for MCP server references
        for event in hooks.events {
            for handler in event.resolvedHandlers {
                // Extract MCP server ID from handler
                guard let serverId = extractMcpServerId(from: handler) else { continue }

                guard !configuredServerIDs.contains(serverId) else { continue }

                // MCP server is referenced but not configured
                let source = handler.source.map { ValidationSourceReference(resolutionSource: $0) }

                issues.append(
                    ValidationIssue(
                        code: .semantic("mcp.missingServerReference"),
                        severity: .error,
                        category: .semantic,
                        message: "Hook handler references MCP server '\(serverId)' which is not configured in resolved MCP settings.",
                        source: source,
                        keyPath: "hooks.\(event.eventID)",
                        relatedSources: []
                    )
                )
            }
        }

        return issues
    }

    private func checkSandboxBlocksRequiredTool(_ projection: SessionProjection) -> [ValidationIssue] {
        guard let settings = projection.settings else { return [] }
        guard let hooks = projection.hooks else { return [] }

        var issues: [ValidationIssue] = []

        // Get the resolved sandbox.allowedDomains
        let sandboxEntry = settings.entries.first { $0.keyPath == "sandbox" }
        let allowedDomains = extractAllowedDomains(from: sandboxEntry?.value.effectiveValue)

        // If allowedDomains is empty or unrestricted, no blocking possible
        guard !allowedDomains.isEmpty else { return [] }

        // Check each hook handler for HTTP requests
        for event in hooks.events {
            for handler in event.resolvedHandlers {
                guard let url = extractHttpHandlerUrl(from: handler) else { continue }

                // Check if URL domain is in allowedDomains
                guard let domain = extractDomain(from: url) else { continue }

                guard !isAllowedDomain(domain, in: allowedDomains) else { continue }

                // Domain is not allowed by sandbox
                let source = handler.source.map { ValidationSourceReference(resolutionSource: $0) }

                issues.append(
                    ValidationIssue(
                        code: .semantic("sandbox.blocksRequiredTool"),
                        severity: .warning,
                        category: .semantic,
                        message: "Hook handler makes HTTP request to '\(domain)' but sandbox.allowedDomains does not include this domain. Request will be blocked.",
                        source: source,
                        keyPath: "hooks.\(event.eventID)",
                        relatedSources: []
                    )
                )
            }
        }

        return issues
    }

    // MARK: - Helper Methods

    private func extractPermissionRules(_ settings: ResolvedSettingsSnapshot, ruleType: String) -> [String] {
        guard let entry = settings.entries.first(where: { $0.keyPath == "permissions" }),
              let permsValue = entry.value.effectiveValue,
              case .object(let permsObj) = permsValue,
              let rulesValue = permsObj[ruleType],
              case .array(let rulesArray) = rulesValue else {
            return []
        }

        return rulesArray.compactMap { value in
            guard case .string(let rule) = value else { return nil }
            return rule
        }
    }

    private func ruleMatches(denyRule: String, allowRule: String) -> Bool {
        // Exact match: identical rules always shadow each other
        if denyRule == allowRule { return true }

        // Wildcard prefix matching: bash:* shadows bash: ls, etc.
        guard denyRule.hasSuffix("*") else { return false }
        let denyPrefix = denyRule.replacingOccurrences(of: "*", with: "")
        let allowPrefix = allowRule.prefix(denyPrefix.count)
        return String(allowPrefix) == denyPrefix
    }

    private func findPermissionRuleSource(_ settings: ResolvedSettingsSnapshot, rule: String) -> ValidationSourceReference? {
        guard let entry = settings.entries.first(where: { $0.keyPath == "permissions" }) else {
            return nil
        }
        guard let winningSource = entry.value.winningSource else { return nil }
        return ValidationSourceReference(resolutionSource: winningSource)
    }

    private func findDuplicateStrings(_ array: [JSONValue]) -> [(rule: String, count: Int)] {
        var counts: [String: Int] = [:]

        for value in array {
            guard case .string(let rule) = value else { continue }
            counts[rule, default: 0] += 1
        }

        return counts
            .filter { $0.value > 1 }
            .map { (rule: $0.key, count: $0.value) }
            .sorted { $0.rule < $1.rule }
    }

    private func extractAllowedDomains(from value: JSONValue?) -> Set<String> {
        guard let value = value,
              case .object(let obj) = value,
              let allowedValue = obj["allowedDomains"],
              case .array(let domains) = allowedValue else {
            return []
        }

        let domainSet = domains.compactMap { value -> String? in
            guard case .string(let domain) = value else { return nil }
            return domain
        }

        return Set(domainSet)
    }

    private func extractMcpServerId(from handler: ResolvedHookHandler) -> String? {
        // MCP handlers have rawType == "mcp" and serverId in the raw object
        guard handler.rawType == "mcp" else { return nil }
        guard case .object(let obj) = handler.rawObject,
              case .string(let serverId) = obj["server_id"] else {
            return nil
        }
        return serverId
    }

    private func extractHttpHandlerUrl(from handler: ResolvedHookHandler) -> String? {
        guard handler.handlerType == .http else { return nil }
        return handler.url
    }

    private func extractDomain(from url: String) -> String? {
        guard let urlComponent = URLComponents(string: url) else { return nil }
        return urlComponent.host
    }

    private func isAllowedDomain(_ domain: String, in allowedDomains: Set<String>) -> Bool {
        // Check exact match
        if allowedDomains.contains(domain) { return true }

        // Check wildcard matches (e.g., *.example.com matches api.example.com)
        for allowed in allowedDomains {
            if allowed.hasPrefix("*.") {
                let suffix = String(allowed.dropFirst(2))
                if domain == suffix || domain.hasSuffix("." + suffix) {
                    return true
                }
            }
        }

        return false
    }
}
