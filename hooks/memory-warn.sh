#!/bin/bash
# PostToolUse hook: Warn after Write|Edit to MEMORY.md if file is getting large

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

# Check file exists
if [ ! -f "$FILE_PATH" ]; then
    exit 0
fi

# Count actual file lines
LINE_COUNT=$(wc -l < "$FILE_PATH" | tr -d ' ')

# Over 180 lines: critical warning
if [ "$LINE_COUNT" -gt 180 ]; then
    echo "MEMORY.md is ${LINE_COUNT} lines (CRITICAL: near 200-line limit!). Move details to memory/topics/ NOW." >&2
    exit 0
fi

# Over 150 lines: light warning
if [ "$LINE_COUNT" -gt 150 ]; then
    echo "MEMORY.md is ${LINE_COUNT} lines (target: <150). Consider moving details to memory/topics/" >&2
    exit 0
fi

exit 0
