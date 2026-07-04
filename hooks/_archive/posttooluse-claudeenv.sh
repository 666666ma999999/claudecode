#!/usr/bin/env bash
# PostToolUse hook: ~/.claude/skills/ or ~/.claude/hooks/ or settings.json が編集されたら
# 03_ClaudeEnv/ catalog を該当 target だけ再生成する。
# Vault が無いマシンでは silent skip。

set -eu

VAULT="$HOME/Documents/Obsidian Vault"
[ ! -d "$VAULT/03_ClaudeEnv" ] && exit 0

# tool input from stdin (JSON)
input=$(cat 2>/dev/null || echo "{}")
file_path=$(echo "$input" | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
    p = d.get("tool_input", {}).get("file_path") or d.get("file_path") or ""
    print(p)
except Exception:
    print("")
' 2>/dev/null || echo "")

[ -z "$file_path" ] && exit 0

target=""
case "$file_path" in
  */.claude/skills/*/SKILL.md) target="skills" ;;
  */.claude/hooks/*) target="hooks" ;;
  */.claude/settings.json|*/.claude/settings.local.json) target="hooks" ;;
  */.claude/rules/*.md) target="rules" ;;
  */.claude/agents/*.md) target="agents" ;;
  */.claude/commands/*.md) target="commands" ;;
  */.claude/.mcp.json|*/.claude/plugins/installed_plugins.json) target="mcp" ;;
  *) exit 0 ;;
esac

python3 "$HOME/.claude/scripts/update_claudeenv.py" --target "$target" >/dev/null 2>&1 || true
exit 0
