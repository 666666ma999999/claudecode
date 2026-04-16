#!/bin/bash
# ~/.claude/tests/run_all.sh — 統合テストランナー
# Usage: cd ~/.claude && bash tests/run_all.sh

set -u
CLAUDE_DIR="$(cd "$(dirname "$0")/.." && pwd)"

red()    { printf '\033[31m%s\033[0m' "$*"; }
green()  { printf '\033[32m%s\033[0m' "$*"; }
yellow() { printf '\033[33m%s\033[0m' "$*"; }

PASS=0; FAIL=0; SKIP=0
FAILED_NAMES=()

pass() { printf '  %s %s\n' "$(green PASS)" "$1"; PASS=$((PASS+1)); }
fail() { printf '  %s %s\n' "$(red FAIL)" "$1"; FAIL=$((FAIL+1)); FAILED_NAMES+=("$1"); }
skip() { printf '  %s %s\n' "$(yellow SKIP)" "$1"; SKIP=$((SKIP+1)); }
section() { printf '\n%s\n' "$(yellow "=== $1 ===")"; }

section "Security"

S1_IN=$(python3 -c 'import json; print(json.dumps({"tool_name":"Bash","tool_input":{"command":"p"+"ip install requests"}}))')
S1_OUT=$(echo "$S1_IN" | python3 "$CLAUDE_DIR/hooks/block-host-installs.py" 2>&1)
if echo "$S1_OUT" | grep -q '"deny"'; then pass "S1: host pip install → deny"; else fail "S1: host pip install → deny"; fi

S2_IN=$(python3 -c 'import json; print(json.dumps({"tool_name":"Bash","tool_input":{"command":"docker compose exec dev p"+"ip install requests"}}))')
S2_OUT=$(echo "$S2_IN" | python3 "$CLAUDE_DIR/hooks/block-host-installs.py" 2>&1)
if [ -z "$S2_OUT" ]; then pass "S2: docker-wrapped pip → allow"; else fail "S2: docker-wrapped pip → allow (got: $S2_OUT)"; fi

S3_IN=$(python3 -c 'import json; print(json.dumps({"tool_name":"Bash","tool_input":{"command":"npm install -g @openai/codex"}}))')
S3_OUT=$(echo "$S3_IN" | python3 "$CLAUDE_DIR/hooks/block-host-installs.py" 2>&1)
if [ -z "$S3_OUT" ]; then pass "S3: npm @openai/codex → allow"; else fail "S3: npm @openai/codex → allow (got: $S3_OUT)"; fi

S4_IN=$(python3 -c 'import json; print(json.dumps({"tool_name":"Bash","tool_input":{"command":"bash -c \"p"+"ip install foo\""}}))')
S4_OUT=$(echo "$S4_IN" | python3 "$CLAUDE_DIR/hooks/block-host-installs.py" 2>&1)
if echo "$S4_OUT" | grep -q '"deny"'; then pass "S4: bash -c wrapped install → deny"; else fail "S4: bash -c wrapped install → deny"; fi

S5_MATCHES=$(grep -rlE "(sk-[a-zA-Z0-9]{20,})" "$CLAUDE_DIR/skills/" 2>/dev/null || true)
if [ -z "$S5_MATCHES" ]; then pass "S5: no hardcoded API keys in skills/"; else fail "S5: hardcoded key suspect: $S5_MATCHES"; fi

S6_KEYS=$(python3 -c "
import json, re, os
d = json.load(open(os.path.expanduser('$CLAUDE_DIR/.mcp.json')))
hits = []
def walk(o, p=''):
    if isinstance(o, dict):
        for k,v in o.items(): walk(v, p+'.'+k)
    elif isinstance(o, str):
        if re.search(r'sk-[a-zA-Z0-9]{20,}|xai-[a-zA-Z0-9]{20,}', o):
            hits.append(p)
walk(d)
print('\n'.join(hits))
")
if [ -z "$S6_KEYS" ]; then pass "S6: no literal secrets in .mcp.json"; else fail "S6: literal secret found: $S6_KEYS"; fi

section "Architecture"

A1_FAIL=""
while IFS= read -r name; do
  [ -z "$name" ] && continue
  [ ! -d "$CLAUDE_DIR/extensions/$name" ] && A1_FAIL="$A1_FAIL $name"
done < <(python3 -c "
import re
for line in open('$CLAUDE_DIR/extensions/extension-registry.yaml'):
    m = re.match(r'^  (\w[\w-]+):\s+true', line)
    if m: print(m.group(1))
")
if [ -z "$A1_FAIL" ]; then pass "A1: registry entries match dirs"; else fail "A1: missing dirs:$A1_FAIL"; fi

A2_MATCHES=$(grep -rl "claude_md_section" "$CLAUDE_DIR/extensions/" 2>/dev/null || true)
if [ -z "$A2_MATCHES" ]; then pass "A2: no claude_md_section remains"; else fail "A2: remains: $A2_MATCHES"; fi

if [ ! -d "$CLAUDE_DIR/extensions/_build_tool" ]; then pass "A3: _build_tool deleted"; else fail "A3: _build_tool still exists"; fi

A4_MATCHES=$(grep -rl "direnv" "$CLAUDE_DIR/rules/" "$CLAUDE_DIR/extensions/" 2>/dev/null || true)
if [ -z "$A4_MATCHES" ]; then pass "A4: no direnv refs in rules/extensions"; else fail "A4: direnv refs: $A4_MATCHES"; fi

A5_FAIL=""
for f in "$CLAUDE_DIR/extensions/"*/extension.yaml; do
  python3 -c "import yaml; yaml.safe_load(open('$f'))" 2>/dev/null || A5_FAIL="$A5_FAIL $(basename $(dirname $f))"
done
if [ -z "$A5_FAIL" ]; then pass "A5: all extension.yaml parse OK"; else fail "A5: parse failed:$A5_FAIL"; fi

# git-safety-reference の .envrc はコミット禁止ファイル列挙（正当）
A6_MATCHES=$(grep -rl "direnv\|source_env_if_exists" "$CLAUDE_DIR/skills/" 2>/dev/null | grep -v "git-safety-reference" || true)
if [ -z "$A6_MATCHES" ]; then pass "A6: no direnv workflow refs in skills/"; else fail "A6: direnv in skills: $A6_MATCHES"; fi

A7_MATCHES=$(grep -l "_build_tool\|build-manifest" "$CLAUDE_DIR/hooks/"*.{sh,py} "$CLAUDE_DIR/scripts/"*.sh 2>/dev/null || true)
if [ -z "$A7_MATCHES" ]; then pass "A7: no _build_tool refs in hooks/scripts"; else fail "A7: _build_tool refs: $A7_MATCHES"; fi

section "Hooks"

H1_IN=$(python3 -c "import json; print(json.dumps({'tool_name':'Write','tool_input':{'file_path':'$HOME/.claude/memory/foo.md'},'cwd':'/tmp/other'}))")
H1_OUT=$(echo "$H1_IN" | bash "$CLAUDE_DIR/hooks/restrict-cwd-edits.sh" 2>/dev/null)
if [ -z "$H1_OUT" ]; then pass "H1: ~/.claude/ allowed across cwd"; else fail "H1: ~/.claude/ should allow (got: $H1_OUT)"; fi

H2_IN=$(python3 -c "import json; print(json.dumps({'tool_name':'Write','tool_input':{'file_path':'/tmp/outside/x.py'},'cwd':'$HOME/proj'}))")
H2_OUT=$(echo "$H2_IN" | bash "$CLAUDE_DIR/hooks/restrict-cwd-edits.sh" 2>/dev/null)
if echo "$H2_OUT" | grep -q '"deny"'; then pass "H2: CWD-outside → deny"; else fail "H2: CWD-outside should deny (got: $H2_OUT)"; fi

if diff -q "$CLAUDE_DIR/hooks/block-host-installs.py" "$CLAUDE_DIR/extensions/docker-safety/hooks/block-host-installs.py" >/dev/null 2>&1; then
  pass "H3: docker-safety hook in sync with root"
else
  fail "H3: block-host-installs.py diverges"
fi

H4_FAIL=""
for f in "$CLAUDE_DIR/hooks/"*.sh "$CLAUDE_DIR/hooks/"*.py; do
  [ -e "$f" ] || continue
  [ -x "$f" ] || H4_FAIL="$H4_FAIL $(basename $f)"
done
if [ -z "$H4_FAIL" ]; then pass "H4: all hooks executable"; else fail "H4: not executable:$H4_FAIL"; fi

for h in plan-quality-check.sh plan-drift-warn.sh plan-readiness-check.sh verify-step-guard.sh auto-git-push.sh; do
  [ -f "$CLAUDE_DIR/hooks/$h" ] && pass "H5-$h: exists" || fail "H5-$h: missing"
done

H6_MATCHES=$(grep -l "extensions/" "$CLAUDE_DIR/hooks/auto-git-push.sh" 2>/dev/null || true)
if [ -n "$H6_MATCHES" ]; then pass "H6: auto-git-push stages extensions/"; else fail "H6: auto-git-push missing extensions/"; fi

section "Skills"

for s in implementation-checklist task-progress secret-management project-bootstrap execution-patterns debugging-guide obsidian-now-done; do
  [ -f "$CLAUDE_DIR/skills/$s/SKILL.md" ] && pass "K1-$s: SKILL.md exists" || fail "K1-$s: missing"
done

K2_FAIL=""
for f in "$CLAUDE_DIR/skills/"*/SKILL.md; do
  grep -q "^name:" "$f" && grep -q "^description:" "$f" || K2_FAIL="$K2_FAIL $(basename $(dirname $f))"
done
if [ -z "$K2_FAIL" ]; then pass "K2: all skills have name/description"; else fail "K2: frontmatter missing:$K2_FAIL"; fi

K3_FAIL=""
for d in "$CLAUDE_DIR/skills/"*/; do
  [ -d "$d" ] || continue
  [ -f "${d}SKILL.md" ] || K3_FAIL="$K3_FAIL $(basename $d)"
done
if [ -z "$K3_FAIL" ]; then pass "K3: no orphan skill dirs"; else fail "K3: missing SKILL.md:$K3_FAIL"; fi

K4_DUPS=$(grep -h "^name:" "$CLAUDE_DIR/skills/"*/SKILL.md 2>/dev/null | sort | uniq -d || true)
if [ -z "$K4_DUPS" ]; then pass "K4: no duplicate skill names"; else fail "K4: dups: $K4_DUPS"; fi

section "MCP"

if python3 -c "import json; json.load(open('$CLAUDE_DIR/.mcp.json'))" 2>/dev/null; then
  pass "M1: .mcp.json JSON valid"
else
  fail "M1: .mcp.json JSON invalid"
fi

M2_MISSING=""
M2_VARS=$(python3 -c "
import json, re
t = open('$CLAUDE_DIR/.mcp.json').read()
print('\n'.join(sorted(set(re.findall(r'\\\$\{([^}]+)\}', t)))))
")
while IFS= read -r var; do
  [ -z "$var" ] && continue
  [ -z "${!var:-}" ] && M2_MISSING="$M2_MISSING $var"
done <<< "$M2_VARS"
if [ -z "$M2_MISSING" ]; then pass "M2: all \${VAR} set in env"; else skip "M2: unset:$M2_MISSING"; fi

M3_RESULT=$(python3 -c "
import json, os
d = json.load(open('$CLAUDE_DIR/.mcp.json'))
hits=[]
for n,s in d.get('mcpServers',{}).items():
    c = s.get('command','')
    if c.startswith('/') and not os.path.exists(c):
        hits.append(n+':'+c)
print('\n'.join(hits))
")
if [ -z "$M3_RESULT" ]; then pass "M3: absolute command paths exist"; else fail "M3: missing: $M3_RESULT"; fi

section "Plan-mode (existing suite)"

PLAN_SCRIPT="$CLAUDE_DIR/tests/plan-mode/run_tests.sh"
if [ ! -f "$PLAN_SCRIPT" ]; then
  skip "plan-mode/run_tests.sh not found"
else
  PLAN_OUT=$(bash "$PLAN_SCRIPT" 2>&1)
  PLAN_EXIT=$?
  # ANSI コード除去後に抽出
  SUB_PASS=$(echo "$PLAN_OUT" | python3 -c "import sys,re; t=re.sub(r'\x1b\[[0-9]*m','',sys.stdin.read()); m=re.search(r'PASSED:\s*(\d+)',t); print(m.group(1) if m else 0)")
  SUB_FAIL=$(echo "$PLAN_OUT" | python3 -c "import sys,re; t=re.sub(r'\x1b\[[0-9]*m','',sys.stdin.read()); m=re.search(r'FAILED:\s*(\d+)',t); print(m.group(1) if m else 0)")
  SUB_PASS=${SUB_PASS:-0}; SUB_FAIL=${SUB_FAIL:-0}
  PASS=$((PASS + SUB_PASS)); FAIL=$((FAIL + SUB_FAIL))
  if [ "$PLAN_EXIT" -eq 0 ]; then
    printf '  %s plan-mode suite (%s passed)\n' "$(green PASS)" "$SUB_PASS"
  else
    printf '  %s plan-mode suite (%s failed)\n' "$(red FAIL)" "$SUB_FAIL"
    FAILED_NAMES+=("plan-mode suite")
  fi
fi

printf '\n%s\n' "$(yellow '─── Summary ───')"
printf '%s: %d  %s: %d  %s: %d\n' "$(green passed)" "$PASS" "$(red failed)" "$FAIL" "$(yellow skipped)" "$SKIP"
if [ "${#FAILED_NAMES[@]}" -gt 0 ]; then
  printf '\nFailed:\n'
  for n in "${FAILED_NAMES[@]}"; do printf '  - %s\n' "$n"; done
fi
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
