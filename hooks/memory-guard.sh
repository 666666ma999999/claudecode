#!/bin/bash
# PreToolUse hook: Block Write to MEMORY.md if content exceeds 200 lines

INPUT=$(cat)

# Extract file_path
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.filePath // empty' 2>/dev/null)
if [ -z "$FILE_PATH" ]; then
    FILE_PATH=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('file_path',''))" 2>/dev/null)
fi

# Only check MEMORY.md files
case "$FILE_PATH" in
    */MEMORY.md) ;;
    *) exit 0 ;;
esac

# Count lines in content
LINE_COUNT=$(echo "$INPUT" | jq -r '.tool_input.content // empty' 2>/dev/null | wc -l | tr -d ' ')
if [ -z "$LINE_COUNT" ] || [ "$LINE_COUNT" = "0" ]; then
    LINE_COUNT=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); c=d.get('tool_input',{}).get('content',''); print(len(c.splitlines()))" 2>/dev/null)
fi

# Validate LINE_COUNT is a number
if ! [ "$LINE_COUNT" -gt 0 ] 2>/dev/null; then
    exit 0
fi

# Over 200 lines: deny
if [ "$LINE_COUNT" -gt 200 ]; then
    cat <<HOOKEOF
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"MEMORY.md content is ${LINE_COUNT} lines (limit: 200). Move details to memory/topics/ before writing."}}
HOOKEOF
    exit 0
fi

# Over 150 lines: warn only
if [ "$LINE_COUNT" -gt 150 ]; then
    echo "WARNING: MEMORY.md content is ${LINE_COUNT} lines (target: <150, limit: 200). Consider moving details to memory/topics/" >&2
    exit 0
fi

exit 0
