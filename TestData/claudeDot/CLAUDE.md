# Personal Claude Code Instructions

These instructions apply to all projects.

## Code style

- TypeScript preferred over plain JavaScript for new files
- 2-space indentation for JS/TS/JSON, 4-space for Python and Go
- Single quotes for strings in JS/TS
- No semicolons in TypeScript files
- Trailing commas in multi-line objects and arrays
- `const` by default; `let` only when reassignment is needed; never `var`
- `async/await` over `.then()` chains

## Git

- Concise, imperative commit messages: "Fix login timeout" not "Fixed the login timeout bug"
- Reference issue numbers where relevant: "Fix user avatar upload (#142)"
- Never force-push to `main` or `master`
- Always run tests before committing

## When helping me

- Lead with the answer, explain only if needed
- Show the specific change, not the full file, unless I ask
- If the task is ambiguous, ask one clarifying question before proceeding
- Prefer editing existing files over creating new ones

## Testing

- Jest for Node.js/TypeScript, Vitest for Vite projects
- `describe` / `it` block structure
- Test names should read as full sentences
- Always test the happy path and at least one error case

@~/.claude/instructions/security-reminders.md
