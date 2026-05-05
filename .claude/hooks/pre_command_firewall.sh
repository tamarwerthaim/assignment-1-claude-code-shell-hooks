#!/bin/bash
# =============================================================================
# Pre-Hook 1: Command Firewall
# Purpose:    Block dangerous bash commands before execution.
# Input:      JSON on stdin: {"tool_name":"Bash","tool_input":{"command":"..."},...}
# Exit codes: 0 = allow, 2 = block (dangerous pattern matched)
# =============================================================================

#If there are dangerous lines of code - block!

HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="$HOOK_DIR/config/dangerous_patterns.txt"

# Read entire JSON input from stdin
INPUT="$(cat)"

# Extract tool_name and command from JSON
TOOL_NAME="$(printf '%s' "$INPUT" | grep -o '"tool_name":"[^"]*"' | head -1 | sed 's/"tool_name":"//;s/"//')"
COMMAND="$(printf '%s' "$INPUT" | grep -o '"command":"[^"]*"' | head -1 | sed 's/"command":"//;s/"//')"

# check TOOL_NAME
if [[ "$TOOL_NAME" != "Bash" ]]; then
    exit 0
fi

#check if the file exists
if [[ ! -f "$CONFIG_FILE" ]]; then
    exit 0
fi

while IFS= read -r line; do
    # Skip comments and empty lines
    case "$line" in
        '#'*|'') continue ;;
    esac

    # line- this dangerous commands | COMMAND- command from JSON
    if echo "$COMMAND" | grep -qE "$line"; then
        printf "BLOCKED: Dangerous pattern matched: '%s'\n" "$line" >&2
        exit 2
    fi
done < "$CONFIG_FILE"
exit 0