#!/bin/bash
# =============================================================================
# Pre-Hook 2: Rate Limiter
# Purpose:    Track command count per session, block after exceeding limit.
# Input:      JSON on stdin: {"tool_name":"Bash","tool_input":{"command":"..."},"session_id":"..."}
# Exit codes: 0 = allow (possibly with warning), 2 = blocked (limit exceeded)
# State file: data/.command_count — format per line: session_id|total|type1:N,type2:N,...
# =============================================================================

#Counts the number of commands and blocks when we reach the maximum.

HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="$HOOK_DIR/config/hooks.conf"
DATA_DIR="$HOOK_DIR/data"
DATA_FILE="$DATA_DIR/.command_count"
RESET_FILE="$DATA_DIR/.reset_commands"

# p- Create dir if not exists
mkdir -p "$DATA_DIR"
# Create file if not exists
touch "$DATA_FILE"

# Read entire JSON input from stdin
INPUT="$(cat)"

# Extract command and session_id from JSON
COMMAND="$(printf '%s' "$INPUT" | grep -o '"command":"[^"]*"' | head -1 | sed 's/"command":"//;s/"//')"
SESSION_ID="$(printf '%s' "$INPUT" | grep -o '"session_id":"[^"]*"' | head -1 | sed 's/"session_id":"//;s/"//')"

#z- if == 0
if [[ -z "$SESSION_ID" ]]; then
 SESSION_ID="default"
fi

#exicute the first word in the command (name of command)
CMD_TYPE=$(echo "$COMMAND" | awk '{print $1}')

# read MAX_COMMANDS and WARNING_THRESHOLD from CONFIG_FILE
MAX_COMMANDS=$(grep "^MAX_COMMANDS=" "$CONFIG_FILE" | cut -d '=' -f2)
WARNING_THRESHOLD=$(grep "^WARNING_THRESHOLD=" "$CONFIG_FILE" | cut -d '=' -f2)

# if RESET_FILE exists
if [[ -f "$RESET_FILE" ]]; then
    # v - delete the line that start with SESSION_ID|           do swich
    grep -v "^$SESSION_ID|" "$DATA_FILE" > "${DATA_FILE}.tmp" && mv "${DATA_FILE}.tmp" "$DATA_FILE"
    rm "$RESET_FILE"
fi

# find this SESSION_ID
LINE=$(grep "^$SESSION_ID|" "$DATA_FILE")
# if this SESSION_ID not found
if [ -z "$LINE" ]; then
    TOTAL=0
    BREAKDOWN=""
else
    # session_id|total|breakdown
    TOTAL=$(echo "$LINE" | cut -d'|' -f2)
    BREAKDOWN=$(echo "$LINE" | cut -d'|' -f3)
fi

# inc TOTAL
TOTAL=$((TOTAL + 1))

# if BREAKDOWN = ... CMD_TYPE:....
if [[ "$BREAKDOWN" == *"$CMD_TYPE:"* ]]; then
    CURRENT_COUNT=$(echo "$BREAKDOWN" | grep -o "$CMD_TYPE:[0-9]*" | cut -d ':' -f2)
    NEW_COUNT=$((CURRENT_COUNT + 1))
    # sed- swich
    BREAKDOWN=$(echo "$BREAKDOWN" | sed "s/$CMD_TYPE:$CURRENT_COUNT/$CMD_TYPE:$NEW_COUNT/")
# this commad not exists
else
    if [[ -z "$BREAKDOWN" ]]; then
        BREAKDOWN="$CMD_TYPE:1"
    else
        BREAKDOWN="$BREAKDOWN,$CMD_TYPE:1"
    fi
fi

# delete the old details and add the new details
grep -v "^$SESSION_ID|" "$DATA_FILE" > "${DATA_FILE}.tmp"
echo "$SESSION_ID|$TOTAL|$BREAKDOWN" >> "${DATA_FILE}.tmp"
mv "${DATA_FILE}.tmp" "$DATA_FILE"

# num of commands > MAX_COMMANDS
if [[ "$TOTAL" -gt "$MAX_COMMANDS" ]]; then
    printf "Total: %d\n" "$TOTAL" >&2
    printf "Breakdown: %s\n" "$BREAKDOWN" >&2
    exit 2
# num of commands > WARNING_THRESHOLD (close to MAX_COMMANDS)
elif [ "$TOTAL" -gt "$WARNING_THRESHOLD" ]; then
    printf "WARNING: Session '%s' is approaching the rate limit (%d/%s).\n" "$SESSION_ID" "$TOTAL" "$MAX_COMMANDS" >&2
fi
exit 0
