# Packet 16 — Configuration Dashboard and Scope Contribution Summaries

## Context

The app currently opens cold with no orientation for the user. This packet adds a **Configuration Overview Dashboard** as the default launch view, giving any user immediate orientation. It also adds **Scope Contribution Summaries** to each scope view — panels showing what each scope wins, contributes to, and loses.

**Prerequisites: Packets 01, 09, 14, 15 must be complete.**

## Prerequisites

- Packet 01 (pipeline), Packet 09 (managed resolver), Packet 14 (scope colours), Packet 15 (trace drill-down) complete

## Deliverables

### 1. Configuration Overview Dashboard

Create `ClaudeConfigManager/Features/Dashboard/ConfigurationDashboardView.swift`.

The dashboard is the default view when the app launches (set it as the initial selection in `AppRouter` / `SidebarView`).

**Health summary card** — a prominent card at the top:
- Active scope count (how many scopes have at least one config file)
- Total resolved settings count
- Warning count (amber badge)
- Error count (red badge)
- If zero warnings and errors: "Configuration looks healthy" with a green checkmark

**Compact scope stack** — a horizontal row of scope indicators left-to-right: Managed → User → Project → Project-Local → Session → CLI. Each shows:
- Scope name
- File count badge (number of config files found for that scope)
- Issue badge (errors or warnings from that scope's parse results)
- Active/inactive state — grey out scopes with no files found

**Recent conflicts section** — show the 3 to 5 most "interesting" resolved disagreements. "Interesting" means: the most scopes contributing different values (sort by `provenance.filter { $0.kind != .absent }.count` descending). Each row:
- Key name
- Winning value (truncated if long)
- "X scopes had opinions" secondary label
- Tapping opens the Resolution Trace panel for that key (from Packet 15)

**File discovery summary** — a two-line summary:
- "X config files found across Y scopes"
- If any files are inaccessible or missing that were expected: "Z files could not be read" in amber

**Quick-link grid** — four tappable cards linking to: Permissions, MCP Servers, Hooks, and the Issues view. Each card shows a count (rule count, server count, hook count, issue count).

**Refresh** — a toolbar "Refresh" button that calls `pipeline.run()`. Show a progress indicator while running.

### 2. Add Dashboard to the sidebar

In `SidebarView`, add a "Dashboard" item at the top of the list (above the scope entries). Set it as the default selection using `AppRouter`.

### 3. Scope Contribution Summaries (C4)

In each scope's detail view (Managed, User, Project, Session), add three collapsible panels below the main settings list:

**"Settings this scope wins"** — settings where this scope's value is the effective winner. Count badge in the panel header.

**"Settings this scope contributes to"** — settings where this scope contributed array entries or object sub-keys to a merged result. Count badge. Each row shows the key and the specific values this scope added.

**"Settings this scope loses"** — settings where this scope declared a value but was overridden by a higher-precedence scope. Count badge. Each row shows the key, this scope's value (shown with strikethrough), and which scope beat it.

All three panels are derived from the existing `SessionProjection` — no new resolver logic needed. The data comes from iterating `projection.settings.entries` and checking provenance.

Tapping any row in these panels opens the Resolution Trace panel for that setting.

### 4. Tests

Create `ClaudeConfigManagerTests/Features/DashboardTests.swift`:
- **`testDashboardHealthSummaryCounts`** — construct a mock projection with known issue counts → health card shows correct numbers
- **`testRecentConflictsSortedByParticipantCount`** — inject a projection with three keys, one with 3 scopes and one with 1 → 3-scope key appears first

## Build and Test

```bash
xcodebuild test -project ClaudeConfigManager.xcodeproj -scheme ClaudeConfigManager \
  -destination 'platform=macOS' -quiet 2>&1 | tail -30
```

**Done criteria:**
- App opens to the dashboard by default
- Dashboard shows accurate health summary, scope stack, recent conflicts, and quick links
- Quick links navigate to the correct views
- Refresh button re-runs the pipeline
- Scope contribution summaries appear in each scope view
- All existing tests pass
- Build has zero warnings

## Handover Note

Only create `Documents/16-handoff.md` if work deviated from the plan. Record what was completed, what was not, any data model gaps that prevented accurate conflict sorting, and recommended next step.
