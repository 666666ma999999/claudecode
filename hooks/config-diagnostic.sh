#!/bin/bash
# SessionStart: Config diagnostic - outputs a summary of Claude Code configuration
# Shows rules, skills, hooks, settings, MCP servers, and CLAUDE.md status

INPUT=$(cat)

CWD="$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('cwd', ''))
except:
    print('')
" 2>/dev/null)"

if [[ -z "$CWD" ]]; then
  exit 0
fi

HOME_CLAUDE="$HOME/.claude"

# --- 1. CWD info ---
GIT_REMOTE=""
if [[ -d "$CWD/.git" ]] || git -C "$CWD" rev-parse --git-dir >/dev/null 2>&1; then
  GIT_REMOTE="$(git -C "$CWD" remote get-url origin 2>/dev/null | sed -E 's|^(https?://[^/]+/|git@[^:]+:)||; s|\.git$||')"
fi

if [[ -n "$GIT_REMOTE" ]]; then
  CWD_LINE="$CWD (git: $GIT_REMOTE)"
else
  CWD_LINE="$CWD"
fi

# --- 2. Global rules count ---
GLOBAL_RULES=0
if [[ -d "$HOME_CLAUDE/rules" ]]; then
  GLOBAL_RULES=$(find "$HOME_CLAUDE/rules" -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
fi

# --- 3. Project rules count ---
PROJECT_RULES=0
if [[ -d "$CWD/.claude/rules" ]]; then
  PROJECT_RULES=$(find "$CWD/.claude/rules" -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
fi

# --- 4. Global skills count (directories only) ---
GLOBAL_SKILLS=0
GLOBAL_SKILL_NAMES=()
if [[ -d "$HOME_CLAUDE/skills" ]]; then
  while IFS= read -r d; do
    name="$(basename "$d")"
    # Skip CLAUDE.md and non-directory entries
    [[ -d "$d" ]] || continue
    GLOBAL_SKILL_NAMES+=("$name")
  done < <(find "$HOME_CLAUDE/skills" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)
  GLOBAL_SKILLS=${#GLOBAL_SKILL_NAMES[@]}
fi

# --- 5. Project skills count (directories only) ---
PROJECT_SKILLS=0
PROJECT_SKILL_NAMES=()
if [[ -d "$CWD/.claude/skills" ]]; then
  while IFS= read -r d; do
    name="$(basename "$d")"
    [[ -d "$d" ]] || continue
    PROJECT_SKILL_NAMES+=("$name")
  done < <(find "$CWD/.claude/skills" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)
  PROJECT_SKILLS=${#PROJECT_SKILL_NAMES[@]}
fi

# --- 6. Skills collision detection ---
COLLISIONS=()
if [[ ${#PROJECT_SKILL_NAMES[@]} -gt 0 && ${#GLOBAL_SKILL_NAMES[@]} -gt 0 ]]; then
  for pname in "${PROJECT_SKILL_NAMES[@]}"; do
    for gname in "${GLOBAL_SKILL_NAMES[@]}"; do
      if [[ "$pname" == "$gname" ]]; then
        COLLISIONS+=("$pname")
      fi
    done
  done
fi

SKILLS_LINE="$GLOBAL_SKILLS global + $PROJECT_SKILLS project"
if [[ ${#COLLISIONS[@]} -gt 0 ]]; then
  COLLISION_STR=$(IFS=', '; echo "${COLLISIONS[*]}")
  SKILLS_LINE="$SKILLS_LINE (⚠ collision: $COLLISION_STR)"
fi

# --- 7. Active hooks count ---
SETTINGS_FILE="$HOME_CLAUDE/settings.json"
HOOKS_LINE="N/A"
if [[ -f "$SETTINGS_FILE" ]]; then
  HOOKS_LINE="$(python3 -c "
import json, sys
try:
    with open('$SETTINGS_FILE') as f:
        data = json.load(f)
    hooks = data.get('hooks', {})
    total = 0
    parts = []
    for event_type in ['SessionStart', 'PreToolUse', 'PostToolUse', 'Notification']:
        entries = hooks.get(event_type, [])
        count = 0
        for entry in entries:
            count += len(entry.get('hooks', []))
        if count > 0:
            parts.append(f'{count} {event_type}')
        total += count
    detail = ', '.join(parts)
    print(f'{total} active ({detail})')
except Exception as e:
    print('N/A')
" 2>/dev/null)"
fi

# --- 8. Settings deny/allow rules count ---
DENY_COUNT=0
ALLOW_COUNT=0
if [[ -f "$SETTINGS_FILE" ]]; then
  read DENY_COUNT ALLOW_COUNT < <(python3 -c "
import json
try:
    with open('$SETTINGS_FILE') as f:
        data = json.load(f)
    perms = data.get('permissions', {})
    deny = len(perms.get('deny', []))
    allow = len(perms.get('allow', []))
    print(deny, allow)
except:
    print('0 0')
" 2>/dev/null)
fi

# --- 9. MCP servers count ---
GLOBAL_MCP=0
PROJECT_MCP=0
if [[ -f "$HOME_CLAUDE/.mcp.json" ]]; then
  GLOBAL_MCP="$(python3 -c "
import json
try:
    with open('$HOME_CLAUDE/.mcp.json') as f:
        data = json.load(f)
    print(len(data.get('mcpServers', {})))
except:
    print(0)
" 2>/dev/null)"
fi
if [[ -f "$CWD/.mcp.json" ]]; then
  PROJECT_MCP="$(python3 -c "
import json
try:
    with open('$CWD/.mcp.json') as f:
        data = json.load(f)
    print(len(data.get('mcpServers', {})))
except:
    print(0)
" 2>/dev/null)"
fi

# --- 10. CLAUDE.md existence ---
check_mark() {
  if [[ -f "$1" ]]; then
    echo "✓"
  else
    echo "✗"
  fi
}

GLOBAL_CMD=$(check_mark "$HOME_CLAUDE/CLAUDE.md")
PROJECT_CMD=$(check_mark "$CWD/CLAUDE.md")
LOCAL_CMD=$(check_mark "$CWD/.claude/CLAUDE.md")

# --- Output ---
cat >&2 <<EOF
📋 Config Diagnostic
  CWD: $CWD_LINE
  Rules: $GLOBAL_RULES global + $PROJECT_RULES project
  Skills: $SKILLS_LINE
  Hooks: $HOOKS_LINE
  Settings: $DENY_COUNT deny, $ALLOW_COUNT allow
  MCP: $GLOBAL_MCP global + $PROJECT_MCP project
  CLAUDE.md: $GLOBAL_CMD global, $PROJECT_CMD project, $LOCAL_CMD local
EOF

exit 0
