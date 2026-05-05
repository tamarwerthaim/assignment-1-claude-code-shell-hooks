#!/bin/bash
# =============================================================================
# Post-Hook 5: Syntax Checker
# Purpose:    Run appropriate syntax checker based on file extension after edit.
# Input:      JSON on stdin: {"tool_name":"Edit","tool_input":{"file_path":"..."},...}
# Exit codes: 0 = syntax OK (or no checker), 1 = syntax error (warn, don't block)
# Supported:  .sh/.bash (bash -n), .py (python3 -m py_compile), .c/.h (gcc -fsyntax-only)
# =============================================================================

#Syntax error checker

HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
DATA_DIR="$HOOK_DIR/data"
mkdir -p "$DATA_DIR"

INPUT="$(cat)"

FILE_PATH="$(printf '%s' "$INPUT" | grep -o '"file_path":"[^"]*"' | head -1 | sed 's/"file_path":"//;s/"//')"
SESSION_ID="$(printf '%s' "$INPUT" | grep -o '"session_id":"[^"]*"' | head -1 | sed 's/"session_id":"//;s/"//')"
SESSION_ID=${SESSION_ID:-"default"}

if [[ ! -f "$FILE_PATH" || -z "$FILE_PATH" ]]; then
    exit 0
fi

# Extract file type
EXTENSION="${FILE_PATH##*.}"

# swich case
case "$EXTENSION" in
    sh|bash)
        # check syntax of bash
        ERROR_OUT=$(bash -n "$FILE_PATH" 2>&1)
        EXIT_CODE=$?
        ;;
    py)
        # check syntax of python
        ERROR_OUT=$(python3 -m py_compile "$FILE_PATH" 2>&1)
        EXIT_CODE=$?
        ;;
    c|h)
        # check syntax of C
        ERROR_OUT=$(gcc -fsyntax-only "$FILE_PATH" 2>&1)
        EXIT_CODE=$?
        ;;
    # default
    *)
        printf "No syntax checker for .%s\n" "$EXTENSION" >&2
        exit 0
        ;;
esac

LOG_FILE="$DATA_DIR/session_${SESSION_ID}.log"
LOG_TIME=$(date "+%Y-%m-%d %H:%M:%S")

# if EXIT_CODE isnt 0
if [ ! $EXIT_CODE -eq 0 ]; then
    printf "SYNTAX ERROR in %s:\n%s\n" "$FILE_PATH" "$ERROR_OUT" >&2
    echo "[$LOG_TIME] SYNTAX_ERROR $FILE_PATH ($EXTENSION)" >> "$LOG_FILE"
    exit 1
# EXIT_CODE = 0
else
    printf "Syntax OK: %s\n" "$FILE_PATH"
    echo "[$LOG_TIME] SYNTAX_OK $FILE_PATH ($EXTENSION)" >> "$LOG_FILE"
    exit 0
fi
