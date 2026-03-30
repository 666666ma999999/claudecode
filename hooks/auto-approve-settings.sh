#!/bin/bash
# Auto-approve .claude/ settings access and self-edit permissions
# Only approves requests related to .claude/ directory operations

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.toolName // ""' 2>/dev/null)
FILE_PATH=$(echo "$INPUT" | jq -r '.path // .input.file_path // .input.filePath // ""' 2>/dev/null)

# Auto-approve if the permission is about .claude/ directory access
if [[ "$FILE_PATH" == *"/.claude/"* ]] || [[ "$FILE_PATH" == *".claude/"* ]]; then
  echo '{"hookSpecificOutput": {"hookEventName": "PermissionRequest", "decision": {"behavior": "allow"}}}'
  exit 0
fi

# Auto-approve ExitPlanMode (settings edit session permission)
if [[ "$TOOL_NAME" == "ExitPlanMode" ]] || [[ "$TOOL_NAME" == "ConfigChange" ]]; then
  echo '{"hookSpecificOutput": {"hookEventName": "PermissionRequest", "decision": {"behavior": "allow"}}}'
  exit 0
fi

# For all other permission requests, don't interfere (let user decide)
exit 0
