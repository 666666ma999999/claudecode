#!/bin/bash
# Auto-approve permissions for .claude/ project operations
# Updated for Claude Code v2.0.54+ PermissionRequest payload format
#
# New payload fields:
#   tool_name, tool_input, permission_suggestions[]
# Old payload fields (kept for backward compat):
#   toolName, path, input.file_path, input.filePath

INPUT=$(cat)

# --- Extract fields (new format first, fallback to old) ---
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // .toolName // ""' 2>/dev/null)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.filePath // .path // .input.file_path // .input.filePath // ""' 2>/dev/null)
BASH_CMD=$(echo "$INPUT" | jq -r '.tool_input.command // .input.command // ""' 2>/dev/null)
CWD=$(echo "$INPUT" | jq -r '.cwd // ""' 2>/dev/null)

# --- Helper: emit allow decision ---
allow() {
  echo '{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"allow"}}}'
  exit 0
}

# --- Helper: emit allow + persist directory permission ---
allow_with_directories() {
  local dirs="$1"
  cat <<EOFJ
{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"allow","updatedPermissions":[{"type":"addDirectories","directories":${dirs},"destination":"localSettings"}]}}}
EOFJ
  exit 0
}

# ============================================================
# 1. Directory access permissions (addDirectories type)
#    This is the NEW permission type that was causing prompts
# ============================================================
HAS_ADD_DIRS=$(echo "$INPUT" | jq -r '
  .permission_suggestions // [] | map(select(.type == "addDirectories")) | length
' 2>/dev/null)

if [[ "$HAS_ADD_DIRS" -gt 0 ]]; then
  # Extract all directories from addDirectories suggestions
  ADD_DIRS=$(echo "$INPUT" | jq -c '
    [.permission_suggestions[] | select(.type == "addDirectories") | .directories[]]
  ' 2>/dev/null)

  # Auto-approve if ALL directories are under ~/.claude/
  ALL_CLAUDE=$(echo "$INPUT" | jq -r '
    [.permission_suggestions[] | select(.type == "addDirectories") | .directories[]
     | select(test("/\\.claude/|/\\.claude$") | not)] | length
  ' 2>/dev/null)

  if [[ "$ALL_CLAUDE" == "0" ]]; then
    # All directories are under .claude/ — approve and persist
    allow_with_directories "$ADD_DIRS"
  fi

  # Also approve if cwd is inside .claude/ (relative paths like "state/")
  if [[ "$CWD" == *"/.claude"* ]] || [[ "$CWD" == *".claude" ]]; then
    allow_with_directories "$ADD_DIRS"
  fi
fi

# ============================================================
# 2. addRules suggestions — auto-approve if already in allow list
# ============================================================
HAS_ADD_RULES=$(echo "$INPUT" | jq -r '
  .permission_suggestions // [] | map(select(.type == "addRules")) | length
' 2>/dev/null)

if [[ "$HAS_ADD_RULES" -gt 0 ]]; then
  # If we're working inside .claude/, approve rule additions
  if [[ "$CWD" == *"/.claude"* ]] || [[ "$CWD" == *".claude" ]]; then
    allow
  fi
fi

# ============================================================
# 3. File path based auto-approval (.claude/ operations)
# ============================================================
if [[ -n "$FILE_PATH" ]]; then
  if [[ "$FILE_PATH" == *"/.claude/"* ]] || [[ "$FILE_PATH" == *".claude/"* ]]; then
    allow
  fi
  # Relative path inside .claude/ cwd
  if [[ "$CWD" == *"/.claude"* ]] || [[ "$CWD" == *".claude" ]]; then
    # If cwd is .claude/, any relative path is inside .claude/
    allow
  fi
fi

# ============================================================
# 4. Bash commands operating on .claude/ paths
# ============================================================
if [[ "$TOOL_NAME" == "Bash" ]] && [[ -n "$BASH_CMD" ]]; then
  if [[ "$BASH_CMD" == *"/.claude/"* ]] || [[ "$BASH_CMD" == *".claude/"* ]]; then
    allow
  fi
  # Bash inside .claude/ cwd
  if [[ "$CWD" == *"/.claude"* ]] || [[ "$CWD" == *".claude" ]]; then
    allow
  fi
fi

# ============================================================
# 5. Tool-specific auto-approvals (settings/config tools)
# ============================================================
case "$TOOL_NAME" in
  ExitPlanMode|ConfigChange|EnterPlanMode)
    allow
    ;;
esac

# ============================================================
# 6. For all other permission requests, don't interfere
# ============================================================
exit 0
