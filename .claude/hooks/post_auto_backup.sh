#!/bin/bash
# =============================================================================
# Post-Hook 4: Auto-Backup
# Purpose:    After a file edit, create a timestamped backup with rotation.
# Input:      JSON on stdin: {"tool_name":"Edit","tool_input":{"file_path":"..."},...}
# Exit codes: 0 always (post-hooks should not block)
# Backups:    data/.backups/<basename>.<timestamp>
# Log:        data/session.log
# =============================================================================

#Creates time-stamped backups and deletes when maximum is reached

HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
DATA_DIR="$HOOK_DIR/data"
BACKUP_DIR="$DATA_DIR/.backups"
CONFIG_FILE="$HOOK_DIR/config/hooks.conf"

INPUT="$(cat)"

FILE_PATH="$(printf '%s' "$INPUT" | grep -o '"file_path":"[^"]*"' | head -1 | sed 's/"file_path":"//;s/"//')"
SESSION_ID="$(printf '%s' "$INPUT" | grep -o '"session_id":"[^"]*"' | head -1 | sed 's/"session_id":"//;s/"//')"
#default
SESSION_ID=${SESSION_ID:-"default"}

if [[ ! -f "$FILE_PATH" || -z "$FILE_PATH" ]]; then
    exit 0
fi

TIMESTAMP=$(date +%Y-%m-%d_%H%M%S)

# create BACKUP_DIR if its not exists
mkdir -p "$BACKUP_DIR"

# Extract name of this file
FILE_NAME=$(basename "$FILE_PATH")

# copy claude/hooks/data/.backups/<basename>.<timestamp> to FILE_PATH
cp "$FILE_PATH" "$BACKUP_DIR/$FILE_NAME.$TIMESTAMP"

# wc- count words c- bytes
FILE_SIZE=$(wc -c < "$FILE_PATH")

# time stamp for log
LOG_TIME=$(date "+%Y-%m-%d %H:%M:%S")

LOG_FILE="$DATA_DIR/session_${SESSION_ID}.log"

# add documentation line 
echo "[$LOG_TIME] BACKUP $FILE_PATH -> .backups/$FILE_NAME.$TIMESTAMP ($FILE_SIZE bytes)" >> "$LOG_FILE"

# Extract MAX_BACKUPS from hooks.conf
MAX_BACKUPS=$(grep "MAX_BACKUPS=" "$CONFIG_FILE" 2>/dev/null | cut -d'=' -f2 | tr -d '\r' | xargs)
# default
MAX_BACKUPS=${MAX_BACKUPS:-5}

# wc -l- count lines
COUNT_BACKUPS=$(ls -1 "$BACKUP_DIR/$FILE_NAME."* 2>/dev/null | wc -l)

if (( COUNT_BACKUPS > MAX_BACKUPS )); then
    # ls- list of files , t - Sorts by time , 2>/dev/null - if there are still no backups
    # tail -n +N - take from line N
    ls -1t "$BACKUP_DIR/$FILE_NAME."* 2>/dev/null | tail -n +$((MAX_BACKUPS + 1)) | while read -r FILE_TO_DELETE; do
        rm -f "$FILE_TO_DELETE"
    done
fi

exit 0