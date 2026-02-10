#!/bin/bash
# PreToolUse: Restrict Write/Edit to current working directory + allowed paths
# Blocks file modifications outside the project directory

INPUT=$(cat)

FILE_PATH="$(echo "$INPUT" | python3 -c "
import sys, json, os
try:
    d = json.load(sys.stdin)
    fp = d.get('tool_input', {}).get('file_path', '')
    print(os.path.realpath(fp) if fp else '')
except:
    print('')
" 2>/dev/null)"

CWD="$(echo "$INPUT" | python3 -c "
import sys, json, os
try:
    d = json.load(sys.stdin)
    cwd = d.get('cwd', '')
    print(os.path.realpath(cwd) if cwd else '')
except:
    print('')
" 2>/dev/null)"

# If we couldn't extract paths, allow (fail open)
if [[ -z "$FILE_PATH" ]] || [[ -z "$CWD" ]]; then
  exit 0
fi

# Always allow: Claude memory/settings/skills (needed for MEMORY.md updates etc.)
if [[ "$FILE_PATH" == "$HOME/.claude/"* ]]; then
  exit 0
fi

# Check if FILE_PATH is within CWD
CWD_PREFIX="${CWD}/"
if [[ "$FILE_PATH" == "$CWD_PREFIX"* ]] || [[ "$FILE_PATH" == "$CWD" ]]; then
  exit 0
fi

# Block: file is outside project directory
cat >&2 <<EOF
Edit blocked: File is outside current working directory
  Attempted: $FILE_PATH
  Project:   $CWD
Only files within the project directory can be edited.
EOF
exit 2
