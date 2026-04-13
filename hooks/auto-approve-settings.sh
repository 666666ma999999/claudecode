#!/bin/bash
# Auto-approve permissions for .claude/ project operations
# Updated for Claude Code v2.0.54+ PermissionRequest payload format
#
# Supports both new (tool_name, tool_input, permission_suggestions)
# and old (toolName, path, input.file_path) payload formats.

INPUT=$(cat)

# --- Single jq call to extract all fields at once ---
eval "$(echo "$INPUT" | jq -r '
  "TOOL_NAME=" + ((.tool_name // .toolName // "") | @sh) + " " +
  "FILE_PATH=" + ((.tool_input.file_path // .tool_input.filePath // .path // .input.file_path // .input.filePath // "") | @sh) + " " +
  "BASH_CMD=" + ((.tool_input.command // .input.command // "") | @sh) + " " +
  "CWD=" + ((.cwd // "") | gsub("/$"; "") | @sh) + " " +
  "HAS_ADD_DIRS=" + (((.permission_suggestions // []) | map(select(.type == "addDirectories")) | length) | tostring | @sh) + " " +
  "HAS_ADD_RULES=" + (((.permission_suggestions // []) | map(select(.type == "addRules")) | length) | tostring | @sh)
' 2>/dev/null)"

# --- CWD predicate (single definition, avoids 4x copy-paste) ---
is_claude_cwd() {
  [[ "$CWD" == *"/.claude" ]] || [[ "$CWD" == *"/.claude/"* ]]
}

# --- Emit allow decision ---
allow() {
  echo '{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"allow"}}}'
  exit 0
}

# --- Emit allow + persist directory permission ---
allow_with_directories() {
  local dirs="$1"
  cat <<EOFJ
{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"allow","updatedPermissions":[{"type":"addDirectories","directories":${dirs},"destination":"localSettings"}]}}}
EOFJ
  exit 0
}

# 1. Directory access (addDirectories)
if [[ "$HAS_ADD_DIRS" -gt 0 ]]; then
  ADD_DIRS=$(echo "$INPUT" | jq -c '
    [.permission_suggestions[] | select(.type == "addDirectories") | .directories[]]
  ' 2>/dev/null)

  ALL_OUTSIDE=$(echo "$INPUT" | jq -r '
    [.permission_suggestions[] | select(.type == "addDirectories") | .directories[]
     | select(test("/\\.claude/|/\\.claude$") | not)] | length
  ' 2>/dev/null)

  if [[ "$ALL_OUTSIDE" == "0" ]]; then
    allow_with_directories "$ADD_DIRS"
  fi
  if is_claude_cwd; then
    allow_with_directories "$ADD_DIRS"
  fi
fi

# 2. addRules — only check if CWD is .claude/
if [[ "$HAS_ADD_RULES" -gt 0 ]] && is_claude_cwd; then
  allow
fi

# 3. File path (.claude/ paths only)
if [[ -n "$FILE_PATH" ]]; then
  if [[ "$FILE_PATH" == *"/.claude/"* ]] || [[ "$FILE_PATH" == *".claude/"* ]]; then
    allow
  fi
fi

# 4. Bash commands referencing .claude/ paths
if [[ "$TOOL_NAME" == "Bash" ]] && [[ -n "$BASH_CMD" ]]; then
  if [[ "$BASH_CMD" == *"/.claude/"* ]] || [[ "$BASH_CMD" == *".claude/"* ]]; then
    allow
  fi
fi

# 5. Any tool when CWD is inside .claude/
if is_claude_cwd; then
  allow
fi

# 6. Settings/config tools
case "$TOOL_NAME" in
  ExitPlanMode|ConfigChange|EnterPlanMode)
    allow
    ;;
esac

# 7. Don't interfere with other requests
exit 0
