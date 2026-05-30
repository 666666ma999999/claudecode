P=$(pwd)
SETTINGS="$P/.claude/settings.local.json"
# Meta-project fallback: when cwd is ~/.claude itself, project-local paths
# collapse (skills live at $P/skills, not $P/.claude/skills).
if [ "$P" = "$HOME/.claude" ]; then
  P_SKILLS="$P/skills"; P_RULES="$P/rules"
else
  P_SKILLS="$P/.claude/skills"; P_RULES="$P/.claude/rules"
fi
# Avoid double-iteration when P_SKILLS == ~/.claude/skills (meta-project).
SKILL_DIRS="$P_SKILLS"
[ "$P_SKILLS" != "$HOME/.claude/skills" ] && SKILL_DIRS="$SKILL_DIRS $HOME/.claude/skills"

# Hooks/MCP source resolution. Hooks live in settings.json (user + project),
# MCP servers live in .mcp.json -- NOT in settings.local.json. The collector
# previously read only $SETTINGS, so on this kind of env it under-reported
# hooks={} / MCP=0. Aggregate the real sources (Claude Code merge order).
if [ "$P" = "$HOME/.claude" ]; then CFG_DIR="$P"; else CFG_DIR="$P/.claude"; fi
HOOK_SOURCES="$HOME/.claude/settings.json $CFG_DIR/settings.json $CFG_DIR/settings.local.json"
MCP_SOURCES="$HOME/.claude/.mcp.json $CFG_DIR/.mcp.json"

echo "=== TIER METRICS ==="
echo "project_files: $(git -C "$P" ls-files 2>/dev/null | wc -l || find "$P" -type f -not -path "*/.git/*" -not -path "*/node_modules/*" -not -path "*/dist/*" -not -path "*/build/*" | wc -l)"
echo "contributors: $(git -C "$P" log -n 500 --format='%ae' 2>/dev/null | sort -u | wc -l)"
echo "ci_workflows:  $(ls "$P/.github/workflows/"*.yml "$P/.github/workflows/"*.yaml 2>/dev/null | wc -l)"
echo "skills:        $(find "$P_SKILLS" -name "SKILL.md" 2>/dev/null | grep -v '/health/SKILL.md' | wc -l)"
echo "claude_md_lines: $(wc -l < "$P/CLAUDE.md" 2>/dev/null)"

echo "=== CLAUDE.md (global) ===" ; cat ~/.claude/CLAUDE.md 2>/dev/null || echo "(none)"
echo "=== CLAUDE.md (local) ===" ; cat "$P/CLAUDE.md" 2>/dev/null || echo "(none)"
echo "=== settings.local.json ===" ; cat "$SETTINGS" 2>/dev/null || echo "(none)"
echo "=== rules/ ===" ; find "$P_RULES" -name "*.md" 2>/dev/null | while IFS= read -r f; do echo "--- $f ---"; cat "$f"; done
echo "=== skill descriptions ===" ; for D in $SKILL_DIRS; do [ -d "$D" ] && grep -r "^description:" "$D" 2>/dev/null; done | sort -u
echo "=== STARTUP CONTEXT ESTIMATE ==="
echo "global_claude_words: $(wc -w < ~/.claude/CLAUDE.md 2>/dev/null | tr -d ' ' || echo 0)"
echo "local_claude_words: $(wc -w < "$P/CLAUDE.md" 2>/dev/null | tr -d ' ' || echo 0)"
echo "rules_words: $(find "$P_RULES" -name "*.md" 2>/dev/null | while IFS= read -r f; do cat "$f"; done | wc -w | tr -d ' ')"
echo "skill_desc_words: $(for D in $SKILL_DIRS; do [ -d "$D" ] && grep -r "^description:" "$D" 2>/dev/null; done | wc -w | tr -d ' ')"
python3 - "$SETTINGS" "$HOOK_SOURCES" "$MCP_SOURCES" <<'PY' 2>/dev/null || echo "(unavailable)"
import json, os, sys
settings_path = sys.argv[1] if len(sys.argv) > 1 else ''
hook_files = (sys.argv[2] if len(sys.argv) > 2 else '').split()
mcp_files  = (sys.argv[3] if len(sys.argv) > 3 else '').split()
HOME = os.path.expanduser('~')

def load(f):
    try:
        return json.load(open(os.path.expanduser(f)))
    except Exception:
        return None

# --- hooks: aggregate event -> entry count across user + project settings ---
print('=== hooks ===')
counts, found, seen = {}, [], set()
for f in hook_files:
    if not f or f in seen:
        continue
    seen.add(f)
    d = load(f)
    if not d:
        continue
    h = d.get('hooks') or {}
    if h:
        found.append(f.replace(HOME, '~'))
    for ev, arr in h.items():
        if isinstance(arr, list):
            counts[ev] = counts.get(ev, 0) + sum(len(m.get('hooks', [])) for m in arr if isinstance(m, dict))
if counts:
    print('source:', ', '.join(found))
    for ev in sorted(counts):
        print(f'{ev}: {counts[ev]}')
    print('total_hook_entries:', sum(counts.values()))
else:
    print('(none found in settings.json / settings.local.json)')

# --- MCP: aggregate server names from .mcp.json (+ settings mcpServers) ---
print('=== MCP ===')
names, src, seen_mcp = [], [], set()
for f in mcp_files:
    if not f or f in seen_mcp:
        continue
    seen_mcp.add(f)
    d = load(f)
    s = (d or {}).get('mcpServers')
    if isinstance(s, dict) and s:
        src.append(f.replace(HOME, '~'))
        for k in s:
            if k not in names:
                names.append(k)
emb = (load(settings_path) or {}).get('mcpServers')
if isinstance(emb, dict):
    for k in emb:
        if k not in names:
            names.append(k)
n = len(names)
print(f'servers({n}):', ', '.join(names))
print('source:', ', '.join(src) or '(none)')
est = n * 25 * 200
print(f'est_tokens: ~{est} ({round(est/2000)}% of 200K)')
print('NOTE: MCP tools are deferred (lazy-loaded via ToolSearch); real startup cost ~0.')
print('      Session-connected servers may exceed config-declared (other .mcp.json / user config).')

# --- MCP FILESYSTEM (from .mcp.json aggregation) ---
print('=== MCP FILESYSTEM ===')
fs = None
for f in mcp_files:
    s = (load(f) or {}).get('mcpServers')
    if isinstance(s, dict) and isinstance(s.get('filesystem'), dict):
        fs = s['filesystem']
        break
a = []
if isinstance(fs, dict):
    a = fs.get('allowedDirectories') or (fs.get('config', {}).get('allowedDirectories') if isinstance(fs.get('config'), dict) else [])
    if not a and isinstance(fs.get('args'), list):
        args = fs['args']
        for i, v in enumerate(args):
            if v in ('--allowed-directories', '--allowedDirectories') and i + 1 < len(args):
                a = [args[i + 1]]; break
        if not a:
            a = [v for v in args if v.startswith('/') or (v.startswith('~') and len(v) > 1)]
print('filesystem_present:', 'yes' if fs else 'no')
print('allowedDirectories:', a or '(missing or not detected)')

# --- allowedTools count (project-local settings) ---
print('=== allowedTools count ===')
print(len((load(settings_path) or {}).get('permissions', {}).get('allow', [])))
PY
echo "=== NESTED CLAUDE.md ===" ; find "$P" -maxdepth 4 -name "CLAUDE.md" -not -path "$P/CLAUDE.md" -not -path "*/.git/*" -not -path "*/node_modules/*" 2>/dev/null || echo "(none)"
echo "=== GITIGNORE ==="
_GITIGNORE_HIT=$(git -C "$P" check-ignore -v .claude/settings.local.json 2>/dev/null || true)
if [ -n "$_GITIGNORE_HIT" ]; then
  _GITIGNORE_SOURCE=${_GITIGNORE_HIT%%:*}
  case "$_GITIGNORE_SOURCE" in
    .gitignore|.claude/.gitignore)
      echo "settings.local.json: gitignored"
      ;;
    *)
      echo "settings.local.json: ignored only by non-project rule ($_GITIGNORE_SOURCE) -- add a repo-local ignore rule"
      ;;
  esac
else
  echo "settings.local.json: NOT gitignored -- risk of committing tokens/credentials"
fi
echo "=== HANDOFF.md ===" ; cat "$P/HANDOFF.md" 2>/dev/null || echo "(none)"
echo "=== MEMORY.md ===" ; cat "$HOME/.claude/projects/-$(pwd | sed 's|[/._]|-|g; s|^-||')/memory/MEMORY.md" 2>/dev/null | head -50 || echo "(none)"

echo "=== CONVERSATION FILES ==="
PROJECT_PATH=$(pwd | sed 's|[/._]|-|g; s|^-||')
CONVO_DIR=~/.claude/projects/-${PROJECT_PATH}
ls -lhS "$CONVO_DIR"/*.jsonl 2>/dev/null | head -10

echo "=== CONVERSATION EXTRACT (up to 3 most recent, confidence improves with more files) ==="
# Skip the active session, it may still be incomplete.
_PREV_FILES=$(ls -t "$CONVO_DIR"/*.jsonl 2>/dev/null | tail -n +2 | head -3)
if [ -n "$_PREV_FILES" ]; then
  echo "$_PREV_FILES" | while IFS= read -r F; do
    [ -f "$F" ] || continue
    echo "--- file: $F ---"
    head -c 2000000 "$F" | jq -r '
      if .type == "user" then "USER: " + ((.message.content // "") | if type == "array" then map(select(.type == "text") | .text) | join(" ") else . end)
      elif .type == "assistant" then
        "ASSISTANT: " + ((.message.content // []) | map(select(.type == "text") | .text) | join("\n"))
      else empty
      end
    ' 2>/dev/null | grep -v "^ASSISTANT: $" | head -300 || echo "(unavailable: jq not installed or parse error)"
  done
else
  echo "(no conversation files)"
fi

echo "=== MCP ACCESS DENIALS ==="
ls -t "$CONVO_DIR"/*.jsonl 2>/dev/null | head -5 | while IFS= read -r F; do
  head -c 1000000 "$F" | grep -Em 2 'Access denied - path outside allowed directories|tool-results/.+ not in ' 2>/dev/null
done | head -20

# --- Skill scan ---
# Exclude self by frontmatter name, stable across install paths.
SELF_SKILL=$( (grep -rl '^name: health$' "$P_SKILLS" "$HOME/.claude/skills" 2>/dev/null || true) | grep 'SKILL.md' | head -1)
[ -z "$SELF_SKILL" ] && SELF_SKILL="health/SKILL.md"

echo "=== SKILL INVENTORY ==="
for DIR in $SKILL_DIRS; do
  [ -d "$DIR" ] || continue
  find -L "$DIR" -name "SKILL.md" 2>/dev/null | grep -v "$SELF_SKILL" | while IFS= read -r f; do
    WORDS=$(wc -w < "$f" | tr -d ' ')
    IS_LINK="no"; LINK_TARGET=""
    SKILL_DIR=$(dirname "$f")
    if [ -L "$SKILL_DIR" ]; then
      IS_LINK="yes"; LINK_TARGET=$(readlink -f "$SKILL_DIR")
    fi
    echo "path=$f words=$WORDS symlink=$IS_LINK target=$LINK_TARGET"
  done
done

echo "=== SKILL FRONTMATTER ==="
for DIR in $SKILL_DIRS; do
  [ -d "$DIR" ] || continue
  find -L "$DIR" -name "SKILL.md" 2>/dev/null | grep -v "$SELF_SKILL" | while IFS= read -r f; do
    if head -1 "$f" | grep -q '^---'; then
      echo "frontmatter=yes path=$f"
      sed -n '2,/^---$/p' "$f" | head -10
    else
      echo "frontmatter=MISSING path=$f"
    fi
  done
done

echo "=== SKILL SYMLINK PROVENANCE ==="
for DIR in $SKILL_DIRS; do
  [ -d "$DIR" ] || continue
  find "$DIR" -maxdepth 1 -type l 2>/dev/null | while IFS= read -r link; do
    TARGET=$(readlink -f "$link")
    echo "link=$(basename "$link") target=$TARGET"
    if [ -d "$TARGET/.git" ]; then
      REMOTE=$(git -C "$TARGET" remote get-url origin 2>/dev/null || echo "unknown")
      COMMIT=$(git -C "$TARGET" rev-parse --short HEAD 2>/dev/null || echo "unknown")
      echo "  git_remote=$REMOTE commit=$COMMIT"
    fi
  done
done

echo "=== SKILL FULL CONTENT (sample: up to 5 skills, 80 lines each) ==="
{ for DIR in $SKILL_DIRS; do
    [ -d "$DIR" ] || continue
    find -L "$DIR" -name "SKILL.md" 2>/dev/null | grep -v "$SELF_SKILL"
  done
} | head -5 | while IFS= read -r f; do
  echo "--- FULL: $f ---"
  head -80 "$f"
done
