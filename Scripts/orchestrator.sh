#!/bin/bash
# =============================================================================
# Claude Config Manager - Implementation Orchestrator
# =============================================================================
# Runs Claude Code CLI in print mode to process implementation packets
# sequentially, running tests after each, and producing reports.
#
# Usage:
#   ./Scripts/orchestrator.sh                    # Run all pending packets
#   ./Scripts/orchestrator.sh --packet G1        # Run a single packet
#   ./Scripts/orchestrator.sh --from H1          # Resume from a specific packet
#   ./Scripts/orchestrator.sh --dry-run          # Preview what would run
#   ./Scripts/orchestrator.sh --status           # Show packet completion status
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPORTS_DIR="$PROJECT_DIR/Documents/orchestrator-reports"
PROMPTS_DIR="$PROJECT_DIR/Scripts/packet-prompts"
STATE_FILE="$REPORTS_DIR/.orchestrator-state.json"
LOG_DIR="$REPORTS_DIR/logs"

# Claude CLI settings
MODEL="${CLAUDE_MODEL:-sonnet}"           # Use sonnet by default (faster + cheaper); set opus for complex packets
MAX_TURNS="${CLAUDE_MAX_TURNS:-25}"       # Max agentic turns per packet
MAX_BUDGET="${CLAUDE_MAX_BUDGET:-5.00}"   # USD budget cap per packet
ALLOWED_TOOLS="Bash(xcodebuild *),Bash(swift *),Bash(git *),Bash(cat *),Bash(ls *),Bash(find *),Bash(mkdir *),Bash(cp *),Bash(mv *),Read,Edit,Write,Glob,Grep,Agent"

# Packet execution order (respects dependency graph from IMPLEMENTATION_PLAN_V2.md)
PACKET_ORDER=(
    # Phase 1: Foundation
    "G1" "G2"
    # Phase 2: Managed Tier (Critical)
    "M1" "M2" "M3" "M4"
    # Phase 3: Permissions + MCP Controls (Critical)
    "P1" "P2" "P3"
    # Phase 4: Hook System (Critical)
    "H1" "H2" "H3"
    # Phase 5: Model, Auth, Sandbox (High)
    "S1" "S2" "S3" "S4"
    # Phase 6: claude.json completion (High)
    "J1"
    # Phase 7: Remaining keys (Medium)
    "U1" "U2"
    # Phase 8: Resolver integration (High)
    "R1" "R2" "R3"
    # Phase 9: Session UI (High)
    "V1" "V2" "V3" "V4"
    # Phase 10: Validation (Medium)
    "E4" "E5"
    # Phase 11: Optional
    "FC1"
)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
timestamp() { date +"%Y-%m-%d %H:%M:%S"; }
log() { echo "[$(timestamp)] $*"; }
log_error() { echo "[$(timestamp)] ERROR: $*" >&2; }

ensure_dirs() {
    mkdir -p "$REPORTS_DIR" "$LOG_DIR" "$PROMPTS_DIR"
}

# ---------------------------------------------------------------------------
# State management (tracks which packets are done)
# ---------------------------------------------------------------------------
init_state() {
    if [[ ! -f "$STATE_FILE" ]]; then
        echo '{"completed":[],"failed":[],"skipped":[]}' > "$STATE_FILE"
    fi
}

is_completed() {
    local packet="$1"
    python3 -c "
import json, sys
state = json.load(open('$STATE_FILE'))
sys.exit(0 if '$packet' in state.get('completed',[]) else 1)
" 2>/dev/null
}

mark_completed() {
    local packet="$1"
    python3 -c "
import json
state = json.load(open('$STATE_FILE'))
if '$packet' not in state['completed']:
    state['completed'].append('$packet')
# Remove from failed if it was there
state['failed'] = [p for p in state['failed'] if p != '$packet']
json.dump(state, open('$STATE_FILE','w'), indent=2)
"
}

mark_failed() {
    local packet="$1"
    local reason="$2"
    python3 -c "
import json
state = json.load(open('$STATE_FILE'))
if '$packet' not in state['failed']:
    state['failed'].append('$packet')
json.dump(state, open('$STATE_FILE','w'), indent=2)
"
}

show_status() {
    echo ""
    echo "=== Orchestrator Status ==="
    echo ""
    python3 -c "
import json
state = json.load(open('$STATE_FILE'))
completed = set(state.get('completed',[]))
failed = set(state.get('failed',[]))
packets = '$( IFS=,; echo "${PACKET_ORDER[*]}" )'.split(',')
for p in packets:
    if p in completed:
        status = 'DONE'
    elif p in failed:
        status = 'FAILED'
    else:
        status = 'pending'
    print(f'  {p:6s}  {status}')
print()
print(f'Completed: {len(completed)}/{len(packets)}')
print(f'Failed:    {len(failed)}')
print(f'Remaining: {len(packets) - len(completed) - len(failed)}')
"
    echo ""
}

# ---------------------------------------------------------------------------
# Test runner
# ---------------------------------------------------------------------------
run_tests() {
    log "Running tests..."
    local test_log="$LOG_DIR/test-$(date +%Y%m%d-%H%M%S).log"

    # Build and test the Xcode project
    if xcodebuild test \
        -project "$PROJECT_DIR/ClaudeConfigManager.xcodeproj" \
        -scheme ClaudeConfigManager \
        -destination 'platform=macOS' \
        -quiet \
        2>&1 | tee "$test_log"; then
        log "Tests PASSED"
        return 0
    else
        log_error "Tests FAILED - see $test_log"
        return 1
    fi
}

# ---------------------------------------------------------------------------
# Build a prompt for a given packet
# ---------------------------------------------------------------------------
build_prompt() {
    local packet_id="$1"
    local prompt_file="$PROMPTS_DIR/${packet_id}.md"

    # If a custom prompt file exists, use it
    if [[ -f "$prompt_file" ]]; then
        cat "$prompt_file"
        return
    fi

    # Otherwise, generate a prompt from the plan
    cat <<PROMPT
You are implementing packet ${packet_id} from the Claude Config Manager gap closure plan.

INSTRUCTIONS:
1. Read Documents/PROJECT_INDEX.md for project conventions.
2. Read Documents/IMPLEMENTATION_PLAN_V2.md and find the section for packet ${packet_id}.
3. Check for any relevant handoff docs in Documents/ (files ending in -handoff.md).
4. Read the relevant existing source files you'll be modifying.
5. Implement the deliverables described in the packet.
6. Write unit tests for all new functionality.
7. Run the tests: xcodebuild test -project ClaudeConfigManager.xcodeproj -scheme ClaudeConfigManager -destination 'platform=macOS' -quiet
8. If tests fail, fix the issues and re-run until they pass.
9. When done, create a handoff document at Documents/${packet_id}-handoff.md containing:
   - Files created or modified
   - Key decisions and assumptions
   - Any issues or open questions
   - Recommended next packet

IMPORTANT RULES:
- Follow existing code patterns and architecture conventions.
- Preserve backward compatibility with existing tests.
- Use the schema-driven approach from G1/G2 for any new settings keys (if those packets are completed).
- Do not modify files outside the scope of this packet.
- If you encounter a blocker that requires human input, write it to Documents/${packet_id}-BLOCKED.md and stop.

Begin by reading the project index and implementation plan.
PROMPT
}

# ---------------------------------------------------------------------------
# Execute a single packet
# ---------------------------------------------------------------------------
execute_packet() {
    local packet_id="$1"
    local session_name="ccm-${packet_id}-$(date +%Y%m%d)"
    local log_file="$LOG_DIR/${packet_id}-$(date +%Y%m%d-%H%M%S).log"
    local report_file="$REPORTS_DIR/${packet_id}-report.md"

    log "=========================================="
    log "Executing packet: ${packet_id}"
    log "Session: ${session_name}"
    log "Log: ${log_file}"
    log "=========================================="

    # Build the prompt
    local prompt
    prompt="$(build_prompt "$packet_id")"

    # Run Claude Code in print mode
    local exit_code=0
    local response
    response=$(cd "$PROJECT_DIR" && claude -p "$prompt" \
        --model "$MODEL" \
        --max-turns "$MAX_TURNS" \
        --allowedTools "$ALLOWED_TOOLS" \
        --output-format json \
        2>"$log_file") || exit_code=$?

    # Extract result text
    local result_text
    result_text=$(echo "$response" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data.get('result', 'No result returned'))
except:
    print(sys.stdin.read() if hasattr(sys.stdin, 'read') else 'Failed to parse response')
" 2>/dev/null || echo "Failed to parse response")

    # Generate report
    cat > "$report_file" <<REPORT
# Packet ${packet_id} - Execution Report

**Date**: $(timestamp)
**Model**: ${MODEL}
**Exit code**: ${exit_code}
**Log**: ${log_file}

## Result

${result_text}

## Post-execution test status

REPORT

    # Check if a BLOCKED file was created
    if [[ -f "$PROJECT_DIR/Documents/${packet_id}-BLOCKED.md" ]]; then
        log_error "Packet ${packet_id} is BLOCKED - human intervention needed"
        echo "**STATUS: BLOCKED** - see Documents/${packet_id}-BLOCKED.md" >> "$report_file"
        mark_failed "$packet_id" "blocked"
        return 2
    fi

    # Run tests to verify
    if [[ $exit_code -eq 0 ]]; then
        if run_tests; then
            echo "**Tests: PASSED**" >> "$report_file"
            mark_completed "$packet_id"
            log "Packet ${packet_id} COMPLETED successfully"
            return 0
        else
            echo "**Tests: FAILED** - see test log" >> "$report_file"

            # Give Claude one chance to fix test failures
            log "Tests failed - giving Claude one retry to fix..."
            local fix_prompt="The tests are failing after implementing packet ${packet_id}. Read the test output, diagnose the failures, fix the code, and re-run the tests. The test command is: xcodebuild test -project ClaudeConfigManager.xcodeproj -scheme ClaudeConfigManager -destination 'platform=macOS' -quiet"

            cd "$PROJECT_DIR" && claude -p "$fix_prompt" \
                --model "$MODEL" \
                --max-turns 10 \
                --allowedTools "$ALLOWED_TOOLS" \
                --output-format text \
                2>>"$log_file" || true

            # Re-run tests after fix attempt
            if run_tests; then
                echo "**Tests: PASSED (after retry)**" >> "$report_file"
                mark_completed "$packet_id"
                log "Packet ${packet_id} COMPLETED after retry"
                return 0
            else
                echo "**Tests: STILL FAILING after retry**" >> "$report_file"
                mark_failed "$packet_id" "tests_failing"
                log_error "Packet ${packet_id} FAILED - tests still failing after retry"
                return 1
            fi
        fi
    else
        echo "**Claude exited with error code ${exit_code}**" >> "$report_file"
        mark_failed "$packet_id" "claude_error"
        log_error "Packet ${packet_id} FAILED - Claude exited with code ${exit_code}"
        return 1
    fi
}

# ---------------------------------------------------------------------------
# Summary report
# ---------------------------------------------------------------------------
generate_summary() {
    local summary_file="$REPORTS_DIR/SUMMARY-$(date +%Y%m%d).md"
    cat > "$summary_file" <<SUMMARY
# Orchestrator Run Summary

**Date**: $(timestamp)
**Model**: ${MODEL}

## Packet Results

SUMMARY

    python3 -c "
import json, os
state = json.load(open('$STATE_FILE'))
completed = set(state.get('completed',[]))
failed = set(state.get('failed',[]))
packets = '$( IFS=,; echo "${PACKET_ORDER[*]}" )'.split(',')

for p in packets:
    if p in completed:
        print(f'- [x] **{p}** - Completed')
    elif p in failed:
        print(f'- [ ] **{p}** - FAILED')
    else:
        print(f'- [ ] {p} - Pending')
" >> "$summary_file"

    cat >> "$summary_file" <<SUMMARY

## Action Items

Check any FAILED or BLOCKED packets:
SUMMARY

    # List any blocked files
    for f in "$PROJECT_DIR"/Documents/*-BLOCKED.md; do
        [[ -f "$f" ]] && echo "- $(basename "$f")" >> "$summary_file"
    done

    log "Summary written to: $summary_file"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    ensure_dirs
    init_state

    local mode="all"
    local target_packet=""
    local start_from=""
    local dry_run=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --packet)
                mode="single"
                target_packet="$2"
                shift 2
                ;;
            --from)
                mode="from"
                start_from="$2"
                shift 2
                ;;
            --dry-run)
                dry_run=true
                shift
                ;;
            --status)
                show_status
                exit 0
                ;;
            --reset)
                rm -f "$STATE_FILE"
                init_state
                log "State reset"
                exit 0
                ;;
            --help|-h)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --packet ID     Run a single packet (e.g., --packet G1)"
                echo "  --from ID       Start from a specific packet (e.g., --from H1)"
                echo "  --dry-run       Show what would run without executing"
                echo "  --status        Show completion status of all packets"
                echo "  --reset         Reset all packet state"
                echo "  --help          Show this help"
                echo ""
                echo "Environment variables:"
                echo "  CLAUDE_MODEL       Model to use (default: sonnet)"
                echo "  CLAUDE_MAX_TURNS   Max turns per packet (default: 25)"
                echo "  CLAUDE_MAX_BUDGET  USD budget per packet (default: 5.00)"
                echo "  ANTHROPIC_API_KEY  Your Claude API key"
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    # Verify Claude CLI is available
    if ! command -v claude &>/dev/null; then
        log_error "Claude Code CLI not found. Install with: npm install -g @anthropic-ai/claude-code"
        exit 1
    fi

    # Verify API key
    if [[ -z "${ANTHROPIC_API_KEY:-}" ]]; then
        log_error "ANTHROPIC_API_KEY not set. Export your API key first."
        exit 1
    fi

    # Determine which packets to run
    local packets_to_run=()
    local started=false

    case "$mode" in
        single)
            packets_to_run=("$target_packet")
            ;;
        from)
            for p in "${PACKET_ORDER[@]}"; do
                if [[ "$p" == "$start_from" ]]; then
                    started=true
                fi
                if $started; then
                    packets_to_run+=("$p")
                fi
            done
            ;;
        all)
            for p in "${PACKET_ORDER[@]}"; do
                if ! is_completed "$p"; then
                    packets_to_run+=("$p")
                fi
            done
            ;;
    esac

    if [[ ${#packets_to_run[@]} -eq 0 ]]; then
        log "No packets to run. All done!"
        show_status
        exit 0
    fi

    # Dry run - just show what would execute
    if $dry_run; then
        echo ""
        echo "=== Dry Run - Would execute these packets ==="
        echo ""
        for p in "${packets_to_run[@]}"; do
            echo "  $p"
        done
        echo ""
        echo "Total: ${#packets_to_run[@]} packets"
        echo "Model: $MODEL"
        echo "Max turns: $MAX_TURNS"
        echo "Budget per packet: \$${MAX_BUDGET}"
        exit 0
    fi

    # Execute packets
    log "Starting orchestrator run: ${#packets_to_run[@]} packets to process"
    log "Model: $MODEL | Max turns: $MAX_TURNS | Budget: \$${MAX_BUDGET}/packet"
    echo ""

    local total=${#packets_to_run[@]}
    local current=0
    local failures=0

    for packet in "${packets_to_run[@]}"; do
        ((current++))
        log "[$current/$total] Processing packet: $packet"

        local result=0
        execute_packet "$packet" || result=$?

        case $result in
            0)
                log "[$current/$total] $packet - SUCCESS"
                ;;
            1)
                ((failures++))
                log_error "[$current/$total] $packet - FAILED"
                # Ask whether to continue or abort
                echo ""
                echo "Packet $packet failed. Continue with remaining packets? (y/n)"
                read -r answer
                if [[ "$answer" != "y" && "$answer" != "Y" ]]; then
                    log "Aborting orchestrator run."
                    break
                fi
                ;;
            2)
                ((failures++))
                log_error "[$current/$total] $packet - BLOCKED (needs human input)"
                echo ""
                echo "Packet $packet is blocked. See Documents/${packet}-BLOCKED.md"
                echo "Continue with remaining packets? (y/n)"
                read -r answer
                if [[ "$answer" != "y" && "$answer" != "Y" ]]; then
                    log "Aborting orchestrator run."
                    break
                fi
                ;;
        esac

        echo ""
    done

    # Generate summary
    generate_summary
    show_status

    if [[ $failures -gt 0 ]]; then
        log_error "$failures packet(s) failed or blocked. Review reports in $REPORTS_DIR/"
        exit 1
    fi

    log "All packets completed successfully!"
}

main "$@"
