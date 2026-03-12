#!/bin/bash
# PreToolUse hook: Block Write/Edit to MEMORY.md if content exceeds 200 lines

INPUT=$(cat)

# Extract tool_name and file_path
TOOL_NAME=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_name',''))" 2>/dev/null)
FILE_PATH=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); ti=d.get('tool_input',{}); print(ti.get('file_path','') or ti.get('filePath',''))" 2>/dev/null)

# Only check MEMORY.md files
case "$FILE_PATH" in
    */MEMORY.md) ;;
    *) exit 0 ;;
esac

if [ "$TOOL_NAME" = "Write" ]; then
    # Write: count lines in content directly
    LINE_COUNT=$(echo "$INPUT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
c = d.get('tool_input', {}).get('content', '')
print(len(c.splitlines()))
" 2>/dev/null)
elif [ "$TOOL_NAME" = "Edit" ]; then
    # Edit: simulate old_string→new_string replacement on current file
    LINE_COUNT=$(echo "$INPUT" | python3 -c "
import sys, json, os
d = json.load(sys.stdin)
ti = d.get('tool_input', {})
fp = ti.get('file_path', '') or ti.get('filePath', '')
old = ti.get('old_string', '')
new = ti.get('new_string', '')
if not os.path.isfile(fp):
    print(0)
    sys.exit(0)
with open(fp) as f:
    content = f.read()
# Simulate replacement
if old in content:
    content = content.replace(old, new, 1)
print(len(content.splitlines()))
" 2>/dev/null)
else
    exit 0
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
