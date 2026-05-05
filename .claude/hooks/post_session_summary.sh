#!/bin/bash
# =============================================================================
# Post-Hook 6: Session Summary
# Purpose:    Generate a formatted summary from session.log when Claude stops.
# Input:      JSON on stdin: {"session_id":"...","cwd":"...","stop_hook_active":false}
# Exit codes: 0 always
# IMPORTANT:  Checks stop_hook_active first to prevent infinite loops.
# =============================================================================

#summary

HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
DATA_DIR="$HOOK_DIR/data"

INPUT="$(cat)"

# Extract stop_hook_active from JSON
STOP_HOOK_ACTIVE=$(printf '%s' "$INPUT" | grep -o '"stop_hook_active":[^,}]*' | cut -d':' -f2 | xargs)

if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
    exit 0
fi

SESSION_ID=$(printf '%s' "$INPUT" | grep -o '"session_id":"[^"]*"' | head -1 | sed 's/"session_id":"//;s/"//')
SESSION_ID=${SESSION_ID:-"default"}

LOG_FILE="$DATA_DIR/session_${SESSION_ID}.log"

#s- not empty (size > 0)
if [[ ! -f "$LOG_FILE" || ! -s "$LOG_FILE" ]]; then
    printf '{"systemMessage": "No session activity recorded."}\n'
    exit 0
fi

#── Activity ─────────────────────────
#Total actions
TOTAL_ACTIONS=$(wc -l < "$LOG_FILE")
#Backups made
BACKUPS_MADE=$(grep -c "BACKUP" "$LOG_FILE")

#Syntax ok
SYNTAX_OK=$(grep -c "SYNTAX_OK" "$LOG_FILE")
#Syntax errors
SYNTAX_ERRORS=$(grep -c "SYNTAX_ERROR" "$LOG_FILE")
#Syntax checks
SYNTAX_CHECKS=$((SYNTAX_OK + SYNTAX_ERRORS))
#Period
START_TIME=$(head -n 1 "$LOG_FILE" | awk -F'[][]' '{print $2}')
END_TIME=$(tail -n 1 "$LOG_FILE" | awk -F'[][]' '{print $2}')
#── Most Edited Files ────────────────
#uniq -c - delete double lines and count
#-rn - r- reserved , n- numbers
MOST_EDITED=$(grep "BACKUP" "$LOG_FILE" | awk '{print $4}' | sort | uniq -c | sort -rn | head -n 3)
#── File Types ───────────────────────
FILE_TYPES=$(awk '{print $4}' "$LOG_FILE" | grep -oE '\.[a-zA-Z0-9]+$' | sort | uniq -c)

#File list format
FORMATTED_MOST_EDITED=$(echo "$MOST_EDITED" | awk '{print "  " NR ". " $2 " (" $1 " edits)"}')
#File type format
FORMATTED_FILE_TYPES=$(echo "$FILE_TYPES" | awk '{print "  " $2 " files: " $1}')

REPORT_BODY="╔══════════════════════════════════════╗
║        SESSION SUMMARY REPORT        ║
╚══════════════════════════════════════╝

Session: $SESSION_ID
Period:  $START_TIME -> $END_TIME

── Activity ─────────────────────────
  Total actions: $TOTAL_ACTIONS
  Backups made: $BACKUPS_MADE
  Syntax checks: $SYNTAX_CHECKS
  Syntax errors: $SYNTAX_ERRORS

── Most Edited Files ────────────────
$FORMATTED_MOST_EDITED

── File Types ───────────────────────
$FORMATTED_FILE_TYPES"

ESCAPED_REPORT=$(printf '%s' "$REPORT_BODY" | sed ':a;N;$!ba;s/\n/\\n/g' | sed 's/"/\\"/g')
echo "{\"systemMessage\": \"$ESCAPED_REPORT\"}"

exit 0