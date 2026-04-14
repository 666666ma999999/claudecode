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

# Always allow: Obsidian Vault (project spec MDs managed via Obsidian)
OBSIDIAN_VAULT="$HOME/Documents/Obsidian Vault/"
if [[ "$FILE_PATH" == "$OBSIDIAN_VAULT"* ]]; then
  exit 0
fi

# Always allow: prm projects (cross-project edits from Obsidian workspace)
PRM_DIR="$HOME/Desktop/prm/"
BIZ_DIR="$HOME/Desktop/biz/"
if [[ "$FILE_PATH" == "$PRM_DIR"* ]] || [[ "$FILE_PATH" == "$BIZ_DIR"* ]]; then
  exit 0
fi

# Allow symlinked skills: if realpath resolves to ~/.agents/skills/ but
# the original path (pre-symlink) is within ~/.claude/skills/, permit edit
AGENTS_PREFIX="$HOME/.agents/skills/"
if [[ "$FILE_PATH" == "$AGENTS_PREFIX"* ]]; then
  RELATIVE="${FILE_PATH#$AGENTS_PREFIX}"
  SKILL_NAME="${RELATIVE%%/*}"
  SYMLINK_DIR="$HOME/.claude/skills/$SKILL_NAME"
  if [[ -L "$SYMLINK_DIR" ]]; then
    exit 0
  fi
fi

# Check if FILE_PATH is within CWD
CWD_PREFIX="${CWD}/"
if [[ "$FILE_PATH" == "$CWD_PREFIX"* ]] || [[ "$FILE_PATH" == "$CWD" ]]; then
  exit 0
fi

# Block: file is outside project directory
cat <<HOOKEOF
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Edit blocked: File outside CWD. Attempted: $FILE_PATH, Project: $CWD"}}
HOOKEOF
exit 0
