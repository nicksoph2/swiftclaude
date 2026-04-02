# Packet 31 — Accessibility Pass and Popover Polish

this has not been completed the app will be built and tested and then accesibility will be added

## Context

With all major features in place, this packet performs a complete accessibility audit: VoiceOver labels, keyboard navigation, and adaptive popover sizing. It also ensures all values in the app are selectable and copyable. These are often the last things addressed but are non-negotiable for a quality macOS app.

**Prerequisites: All feature packets (01–30) should be complete or in progress. This packet can be done in any order relative to 27–30.**

## Prerequisites

- Packets 01–26 complete (all core features, diagram, editing, permissions, search)

## Deliverables

### 1. VoiceOver audit (N1)

Systematically open every view in the app with VoiceOver enabled (System Settings → Accessibility → VoiceOver, or use Xcode Accessibility Inspector). For every custom interactive element that VoiceOver reads incorrectly or silently, add the appropriate modifier.

**Required labels** (apply throughout all views encountered):

**Pipeline diagram nodes**:

```swift
.accessibilityLabel("[Stage name] stage")
.accessibilityValue("[Health]: [metric]")
.accessibilityHint("Double-tap to expand this stage")
```

**Scope badges / coloured pills**:

```swift
.accessibilityLabel("[Scope name] scope")
// Remove default colour announcement — colour alone is not accessible
```

**Resolution waterfall rows**:

```swift
.accessibilityLabel("[Key name]")
.accessibilityValue("[value], [Scope name] scope [participation: winning/overridden/merged]")
.accessibilityHint("Double-tap to view resolution trace")
```

**Health indicator dots**:

```swift
.accessibilityLabel("[Stage name]: [N] [warnings/errors]")
// or "healthy" if no issues
```

**Scope contribution dots** (the small circles in diagram nodes):

```swift
.accessibilityElement(children: .combine)
.accessibilityLabel("Contributions from [list of scope names]")
```

**Sidebar scope rows**:

```swift
.accessibilityLabel("[Scope name] scope")
.accessibilityValue("[N] files, [N] issues")
```

**Edit affordance (pencil icon)**:

```swift
.accessibilityLabel("Edit [key name]")
.accessibilityHint("Double-tap to open setting editor")
```

**Lock icon**:

```swift
.accessibilityLabel("[Key name], locked by managed policy")
.accessibilityHint("Double-tap for details")
```

### 2. Accessibility grouping

For compound rows (e.g. a setting row with key name, value, scope badge, and conflict badge), use `accessibilityElement(children: .combine)` to prevent VoiceOver from reading each sub-element separately. The combined label should be: "[Key name]: [value], [scope name] scope[, conflict detected]".

### 3. Responsive popover sizing (N3)

Audit all popover presentations in the app. For every popover that could appear on a narrow window:

- Measure the popover's minimum width
- If the host window is narrower than `popoverMinWidth + 40pt`, switch to `.sheet` presentation

Implement a `AdaptivePresentationModifier`:

```swift
struct AdaptivePresentation: ViewModifier {
    @Environment(\.horizontalSizeClass) var sizeClass
    let isPresented: Binding<Bool>
    let narrowContent: AnyView
    let wideContent: AnyView

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: isPresented.projected(for: .narrow, sizeClass: sizeClass)) {
                narrowContent
            }
            .popover(isPresented: isPresented.projected(for: .wide, sizeClass: sizeClass)) {
                wideContent
            }
    }
}
```

Apply to:

- File detail popovers in the Discovery stage
- Resolution Trace panel
- Editor popover from Edit Mode
- Permissions Inspector
- All other panels that currently use `.popover` unconditionally

Test at window widths: 400pt, 500pt, 800pt, 1200pt.

### 4. Monospace copy-paste (N5)

Audit every `Text` view in the app that shows a key path, file path, setting value, tool invocation, server name, or any monospace-rendered string. Ensure all are copyable:

```swift
// For any monospace text value:
Text(value)
    .font(.system(.body, design: .monospaced))
    .textSelection(.enabled)
```

For longer values that don't fit in `Text`, add a context menu:

```swift
.contextMenu {
    Button("Copy") {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }
}
```

Use Xcode's search to find all `.font(.system(.body, design: .monospaced))` usages and ensure `.textSelection(.enabled)` is applied to each.

### 5. Keyboard focus chain

Verify the Tab-key navigation order is logical in every form and list:

- Editor popover: field → scope picker → Preview button → Save button → Cancel button
- Settings list: rows navigate with arrow keys; Tab exits the list to the toolbar
- Search overlay: search field is auto-focused on open; Escape dismisses

Use `@FocusState` and `.focused($focusState, equals:)` to enforce the correct focus order in custom forms.

### 6. Verification checklist (run manually before marking done)

- [ ] Open Xcode Accessibility Inspector. Navigate the app with Tab and arrow keys only. Verify every interactive element is reachable.
- [ ] Enable VoiceOver and navigate to the Pipeline diagram. Confirm each node is announced with stage name, health, and hint.
- [ ] Enable VoiceOver and navigate the Resolution stage. Confirm a row announces key, value, scope, and participation kind.
- [ ] Resize the window to 450pt width. Confirm all popovers switch to sheets.
- [ ] Right-click a setting value. Confirm "Copy" appears in context menu.
- [ ] Right-click a file path. Confirm it is copyable.

### 7. Tests

- **`testVoiceOverLabelForDiagramNode`** — instantiate a diagram node view with mock data → `accessibilityLabel` is set and contains the stage name
- **`testResolutionRowCombinedLabel`** — a setting row with key, value, scope → combined accessibility label is non-empty and contains all three
- **`testTextSelectionEnabledOnMonospaceValues`** — at minimum assert that the modifier is applied in code by searching for `.textSelection(.enabled)` in the relevant files and confirming its presence

## Build and Test

```bash
xcodebuild test -project ClaudeConfigManager.xcodeproj -scheme ClaudeConfigManager \
  -destination 'platform=macOS' -quiet 2>&1 | tail -30
```

**Done criteria:**

- Manual VoiceOver checklist above is fully completed
- All popovers adapt to sheets on narrow windows
- All monospace values are copyable via context menu or `.textSelection`
- All existing tests pass
- No new VoiceOver-reported "unlabelled button" or "unlabelled image" issues

## Handover Note

Only create `Documents/31-handoff.md` if work deviated from the plan. Record what was completed, what was not, any interactions that are genuinely inaccessible due to platform limitations, and recommended next step.
