#!/bin/bash
# PostToolUse hook: open .md files in Obsidian after Write/Edit (vault only)
# - Only triggers for files under ~/Documents/Obsidian Vault/
# - Only triggers for .md files
# - macOS only (uses `open -a`)

# Read hook input JSON from stdin
json=$(cat)

# Extract file path (Edit returns tool_input.file_path; some tools may use tool_response.filePath)
f=$(echo "$json" | jq -r '.tool_response.filePath // .tool_input.file_path // empty')

# Skip if no path
[ -z "$f" ] && exit 0

# Match: vault path AND .md extension
case "$f" in
  "$HOME/Documents/Obsidian Vault/"*.md)
    open -a Obsidian "$f" 2>/dev/null
    ;;
esac

exit 0
