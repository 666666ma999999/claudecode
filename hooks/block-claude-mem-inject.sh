#!/bin/bash
# Block claude-mem from re-injecting <claude-mem-context> into CLAUDE.md files
input=$(cat)
file=$(echo "$input" | jq -r '.tool_input.file_path // ""')
content=$(echo "$input" | jq -r '.tool_input.content // .tool_input.new_string // ""')
case "$file" in
  */CLAUDE.md)
    if echo "$content" | grep -q '<claude-mem-context>'; then
      echo '{"decision":"deny","reason":"claude-mem context injection blocked. See ~/.claude/state/claude-mem-no-inject sentinel."}'
      exit 0
    fi
    ;;
esac
exit 0
