#!/bin/bash
# =============================================================================
# Pre-Hook 3: Commit Message Validator
# Purpose:    Validate git commit messages follow conventional commit format.
#             Suggests a prefix if one is missing based on staged diff heuristics.
# Input:      JSON on stdin: {"tool_name":"Bash","tool_input":{"command":"..."},...}
# Exit codes: 0 = allow, 2 = block (invalid commit message)
# =============================================================================

#Checking that the prefix is ​​valid and checking the message

HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
PREFIXES_FILE="$HOOK_DIR/config/commit_prefixes.txt"

# Read entire JSON input from stdin
INPUT="$(cat)"

# Extract tool_name and command from JSON
TOOL_NAME="$(printf '%s' "$INPUT" | grep -o '"tool_name":"[^"]*"' | head -1 | sed 's/"tool_name":"//;s/"//')"
COMMAND="$(printf '%s' "$INPUT" | grep -o '"command":"[^"]*"' | head -1 | sed 's/"command":"//;s/"//')"

#check command
if [[ ! "$COMMAND" =~ "git commit" || ! "$COMMAND" =~ "-m" ]]; then
    exit 0
fi

#Extract chars between '\" (.- char , *- before..)
MSG=$(echo "$COMMAND" | grep -oE "['\"].*['\"]") 
#delete '\" (^- first char in this line, $- last char in this line)
MSG=$(echo "$MSG" | sed 's/^.//;s/.$//') 

# check if PREFIXS_FILE is exists
if [ -f "$PREFIXS_FILE" ]; then
    #change to one line with |
    LIST_PREFIXES=$(paste -sd "|" "$PREFIXES_FILE")
else
    LIST_PREFIXES="feat|fix|docs|refactor|test|chore"
fi

#^(feat|fix|docs|refactor|test|chore):
PREFIX_REGEX="^($LIST_PREFIXES): "

#if MSG dont start with word from feat|fix|docs|refactor|test|chore
if [[ ! "$MSG" =~ $PREFIX_REGEX ]]; then

    # names files (A- add , M- change , D- delete)
    STAGED_FILES=$(git diff --cached --name-status)
    # how many lines are added or deleted
    DIFF_STAT=$(git diff --cached --stat)
    # default
    SUGGESTION="feat"

    # pattern test \ spec
    if [[ "$STAGED_FILES" =~ "test" || "$STAGED_FILES" =~ "spec" ]]; then
        SUGGESTION="test"
    # pattern README \ .md
    elif [[ "$STAGED_FILES" =~ "README" || "$STAGED_FILES" =~ ".md" ]]; then
        SUGGESTION="docs"
    # start with A (q- without print)
    elif echo "$STAGED_FILES" | grep -q "^A"; then
        SUGGESTION="feat"
    # More deletions than insertions
    else
        # o- find just this  awk- columns
        INSERTIONS=$(echo "$DIFF_STAT" | grep -o "[0-9]* insertion" | awk '{print $1}')
        DELETIONS=$(echo "$DIFF_STAT" | grep -o "[0-9]* deletion" | awk '{print $1}')
        # -0 - if empty put 0
        if [[ "${DELETIONS:-0}" -gt "${INSERTIONS:-0}" ]]; then
        SUGGESTION="refactor"
        fi
    fi  
    printf "BLOCKED: Missing commit prefix. Based on your changes, try: '%s: %s'\n" "$SUGGESTION" "$MSG" >&2
    printf "Valid prefixes: %s\n" "${LIST_PREFIXES//|/, }" >&2
    exit 2
fi

# length of MSG
MSG_LEN=${#MSG}
# Message length must be 10-72 characters
if (( MSG_LEN < 10 || MSG_LEN > 72 )); then
    printf "BLOCKED: Message length must be 10-72 characters (current: %d).\n" "$MSG_LEN" >&2
    exit 2
fi

# MSG end with a period (.)
if [[ "$MSG" == *. ]]; then
    printf "BLOCKED: Message must not end with a period.\n" >&2
    exit 2
fi

exit 0


