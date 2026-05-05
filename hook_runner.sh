#!/bin/bash
# =============================================================================
# Hook Runner
# Purpose:    Standalone simulator of Claude Code's hook execution for testing.
#             Reads hooks_config.txt, matches event+tool, runs hooks in order.
# Usage:      echo '<json>' | ./hook_runner.sh <event_type> <tool_name>
# Examples:
#   echo '{"tool_name":"Bash","tool_input":{"command":"ls -la"},"session_id":"s1"}' \
#       | ./hook_runner.sh PreToolUse Bash
#   echo '{"tool_name":"Edit","tool_input":{"file_path":"main.c"},"session_id":"s1"}' \
#       | ./hook_runner.sh PostToolUse Edit
# =============================================================================

# ── Colour codes ───────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

RUNNER_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="$RUNNER_DIR/hooks_config.txt"

# ── Argument validation ────────────────────────────────────────────────────────
if [ -z "$1" ] || [ -z "$2" ]; then
    printf '%bUsage:%b echo '"'"'<json>'"'"' | %s <event_type> <tool_name>\n' "$BOLD" "$RESET" "$0"
    printf '\n'
    printf 'event_type examples: PreToolUse, PostToolUse, Stop\n'
    printf 'tool_name  examples: Bash, Edit, Write, MultiEdit, *\n'
    printf '\n'
    printf 'Config file: %s\n' "$CONFIG_FILE"
    exit 1
fi

EVENT_TYPE="$1"
TOOL_NAME="$2"

# ── Validate config file ───────────────────────────────────────────────────────
if [ ! -f "$CONFIG_FILE" ]; then
    printf '%bERROR:%b Config file not found: %s\n' "$RED" "$RESET" "$CONFIG_FILE" >&2
    exit 1
fi

# ── Read stdin into temp file (hooks need to re-read it) ──────────────────────
TEMP_FILE="$(mktemp)"
trap 'rm -f "$TEMP_FILE"' EXIT
cat > "$TEMP_FILE"

printf '%b─── Hook Runner (%s / %s) ───%b\n' "$BOLD" "$EVENT_TYPE" "$TOOL_NAME" "$RESET"
printf '\n'

# ── Statistics ────────────────────────────────────────────────────────────────
MATCHED=0
PASSED=0
BLOCKED=0
WARNINGS=0
FINAL_EXIT=0

while read -r line; do
    # empty line or lines starting with '#'
    if [[ -z "$line" || "$line" =~ ^#  ]]; then
        continue
    fi

    # Split the line on ':' 
    # | - do right in left
    CONF_EVENT=$(echo "$line" | cut -d ':' -f1)
    CONF_MATCHER=$(echo "$line" | cut -d':' -f2)
    CONF_SCRIPT=$(echo "$line" | cut -d':' -f3-)

    #check arg 1
    if [[ "$CONF_EVENT" != "$EVENT_TYPE" ]]; then
        continue
    fi
    #check arg 2
    if [[ "$CONF_MATCHER" != "$TOOL_NAME" && "$CONF_MATCHER" != '*' ]]; then
        continue
    fi
    #increment matched count
    ((MATCHED++))

    #script pass
    if [[ "$CONF_SCRIPT" == ./* ]]; then
        CONF_SCRIPT="${RUNNER_DIR}/${CONF_SCRIPT}"
    fi

    #print running hook script (pass)
    echo "${CYAN} Running hook script: ${CONF_SCRIPT} ${RESET}"

    #mktemp - temp file
    STDERR_FILE=$(mktemp)
    # enter JSON (the stdin in TEMP_FILE) to hook script
    # enter errors to STDERR_FILE (if..)
    "$CONF_SCRIPT" < "$TEMP_FILE" 2> "$STDERR_FILE"
    # $? - the last answer
    EXIT_CODE=$?

    if [[ "$EXIT_CODE" -eq 0 ]]; then
        echo "${GREEN}✓ Passed ${RESET}"
        ((PASSED++))
    elif [[ "$EXIT_CODE" -eq 2 ]]; then
        echo "${RED}✗ BLOCKED ${RESET}"
        # s - size (>0)
        if [[ -s STDERR_FILE ]]; then
            echo "Error output: "
            #cat- read from file
            cat "$STDERR_FILE"
        fi
        ((BLOCKED++))
        FINAL_EXIT=2
        echo "Chain stopped"
        break
    else
        echo "${YELLOW}⚠ Warning (exit $EXIT_CODE)${RESET}"
        # s - size (>0)
        if [[ -s STDERR_FILE ]]; then
            echo "Error output: "
            #cat- read from file
            cat "$STDERR_FILE"
        fi
        ((WARNINGS++))
    fi

    #Print a blank line
    echo ""

done < "hooks_config.txt"

# =============================================================================
# TODO: Process the config file line by line.
#
# For each line in hooks_config.txt:
#   1. Skip comments (lines starting with '#') and empty lines.
#   2. Split the line on ':' to get three fields:
#        CONF_EVENT   — the hook event type (e.g. PreToolUse)
#        CONF_MATCHER — the tool matcher (e.g. Bash, Edit, or * for all)
#        CONF_SCRIPT  — the path to the hook script (rest of line after second ':')
#   3. Skip the line if CONF_EVENT does not match EVENT_TYPE.
#   4. Skip the line if CONF_MATCHER does not match TOOL_NAME and is not '*'.
#   5. Increment MATCHED.
#   6. Resolve the script path: if CONF_SCRIPT starts with './', prepend RUNNER_DIR.
#   7. Print which script is running (use the CYAN colour).
#   8. Execute the hook script feeding it the saved stdin (TEMP_FILE).
#      Capture stderr separately and save the exit code to EXIT_CODE.
#   9. Based on EXIT_CODE:
#        0  → print green "✓ Passed",  increment PASSED
#        2  → print red   "✗ BLOCKED", print stderr if any, increment BLOCKED,
#             set FINAL_EXIT=2, print chain-stopped message, and break the loop
#        else→ print yellow "⚠ Warning (exit N)", print stderr if any,
#             increment WARNINGS
#  10. Print a blank line after each hook result.
# =============================================================================

# ── Summary ────────────────────────────────────────────────────────────────────
printf '%b─── Hook Execution Summary ──────────%b\n' "$BOLD" "$RESET"
printf 'Matched:  %d hooks\n' "$MATCHED"
printf '%bPassed:   %d%b\n' "$GREEN" "$PASSED" "$RESET"
if [ "$BLOCKED" -gt 0 ]; then
    printf '%bBlocked:  %d%b\n' "$RED" "$BLOCKED" "$RESET"
else
    printf 'Blocked:  %d\n' "$BLOCKED"
fi
if [ "$WARNINGS" -gt 0 ]; then
    printf '%bWarnings: %d%b\n' "$YELLOW" "$WARNINGS" "$RESET"
else
    printf 'Warnings: %d\n' "$WARNINGS"
fi

exit $FINAL_EXIT
