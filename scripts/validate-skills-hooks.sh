#!/bin/bash
# validate-skills-hooks.sh — Local validation for ~/.claude/skills/ and ~/.claude/hooks/.
#
# Checks:
#   - SKILL.md YAML frontmatter parseable
#   - hook scripts pass `bash -n` (syntax)
#   - skill name uniqueness (no duplicates)
#   - allowed-tools list references valid tools
#
# Exit code: 0 if all pass, 1 if any failure.
#
# Designed to be called locally or from GitHub Actions.

set -uo pipefail

CLAUDE_HOME="${HOME}/.claude"
SKILLS_DIR="${CLAUDE_HOME}/skills"
HOOKS_DIR="${CLAUDE_HOME}/hooks"
AGENTS_DIR="${CLAUDE_HOME}/agents"

pass=0
fail=0
warn=0
errors=()

echo "=== 1. SKILL.md frontmatter validation ==="
for skill_md in "$SKILLS_DIR"/*/SKILL.md; do
    [ -f "$skill_md" ] || continue
    skill_name=$(basename "$(dirname "$skill_md")")

    # Extract frontmatter (first --- ... --- block)
    fm=$(awk 'BEGIN{s=0} /^---$/{if(s==0){s=1;next} if(s==1){s=2;exit}} s==1{print}' "$skill_md")

    if [ -z "$fm" ]; then
        errors+=("[skill] $skill_name: missing frontmatter")
        fail=$((fail + 1))
        continue
    fi

    # YAML parse check (python yaml)
    if ! echo "$fm" | python3 -c "import sys, yaml; yaml.safe_load(sys.stdin)" 2>/dev/null; then
        errors+=("[skill] $skill_name: invalid YAML frontmatter")
        fail=$((fail + 1))
        continue
    fi

    # Required fields: name, description
    # NOTE: use grep -c (consumes all stdin) instead of grep -q to avoid SIGPIPE
    # under `set -o pipefail` — grep -q exits on first match and echo gets SIGPIPE.
    if [ "$(echo "$fm" | grep -cE '^name:')" -eq 0 ]; then
        errors+=("[skill] $skill_name: missing 'name' field")
        fail=$((fail + 1))
        continue
    fi
    if [ "$(echo "$fm" | grep -cE '^description:')" -eq 0 ]; then
        errors+=("[skill] $skill_name: missing 'description' field")
        warn=$((warn + 1))
    fi

    pass=$((pass + 1))
done
echo "  passed: $pass / failed: $fail"

echo ""
echo "=== 2. Hook script syntax validation ==="
h_pass=0
h_fail=0
for hook in "$HOOKS_DIR"/*.sh; do
    [ -f "$hook" ] || continue
    if ! bash -n "$hook" 2>/dev/null; then
        err=$(bash -n "$hook" 2>&1)
        errors+=("[hook] $(basename "$hook"): syntax error - ${err}")
        h_fail=$((h_fail + 1))
    else
        h_pass=$((h_pass + 1))
    fi
done
echo "  passed: $h_pass / failed: $h_fail"

echo ""
echo "=== 3. Skill name uniqueness ==="
duplicates=$(for skill_md in "$SKILLS_DIR"/*/SKILL.md; do
    awk '/^name:/{print $2; exit}' "$skill_md"
done | sort | uniq -d)

if [ -n "$duplicates" ]; then
    errors+=("[skill] duplicate names: $duplicates")
    fail=$((fail + 1))
    echo "  ❌ duplicate: $duplicates"
else
    echo "  ✅ all skill names unique"
fi

echo ""
echo "=== 4. allowed-tools validity ==="
# 現行セッションで実在を確認できるビルトインツール（MCP は別扱い）
KNOWN_TOOLS="Read Write Edit NotebookEdit Bash Grep Glob AskUserQuestion WebSearch WebFetch Agent Skill ExitPlanMode EnterPlanMode TaskOutput TaskStop SendMessage CronCreate CronDelete CronList RemoteTrigger PushNotification EnterWorktree ExitWorktree ScheduleWakeup ToolSearch Monitor BashOutput KillShell TodoWrite"
t_warn=0
for skill_md in "$SKILLS_DIR"/*/SKILL.md; do
    [ -f "$skill_md" ] || continue
    skill_name=$(basename "$(dirname "$skill_md")")
    # frontmatter から allowed-tools の角括弧配列・ブロック配列・角括弧なし1行値を抽出
    fm=$(awk 'BEGIN{s=0} /^---$/{if(s==0){s=1;next} if(s==1){s=2;exit}} s==1{print}' "$skill_md")
    tools=$(
        {
            echo "$fm" |
                sed -nE 's/^allowed-tools:[[:space:]]*\[([^]]*)\].*$/\1/p' |
                tr ',' '\n'
            echo "$fm" |
                awk '/^allowed-tools:[[:space:]]*$/{flag=1; next} /^[a-zA-Z_]/{flag=0} flag' |
                sed -nE 's/^[[:space:]]*-[[:space:]]*(.*)$/\1/p'
            echo "$fm" |
                sed -nE '/^allowed-tools:[[:space:]]*\[/d; s/^allowed-tools:[[:space:]]+(.+)$/\1/p' |
                sed -E "s/^[[:space:]'\"]+//; s/[[:space:]'\"]+$//" |
                tr ', ' '\n\n'
        } |
            sed -E "s/^[[:space:]'\"]+//; s/[[:space:]'\"]+$//; s/\([^)]*\)$//" |
            sed '/^$/d'
    )
    for t in $tools; do
        # MCP tools start with mcp__ — skip
        case "$t" in
            mcp__*|\*) continue ;;
        esac
        if ! echo " $KNOWN_TOOLS " | grep -q " $t "; then
            errors+=("[skill] $skill_name: unknown tool '$t' in allowed-tools")
            t_warn=$((t_warn + 1))
        fi
    done
done
echo "  warnings: $t_warn"

echo ""
echo "=== 5. Agent tools validity ==="
a_warn=0
# fail-loud: agents ディレクトリ自体が無いと「0件走査で緑」になり検証が素通りする
if [ ! -d "$AGENTS_DIR" ]; then
    errors+=("[agent] agents dir not found: $AGENTS_DIR (検証が空振りするため配置を確認)")
    a_warn=$((a_warn + 1))
fi
for agent_md in "$AGENTS_DIR"/*.md; do
    [ -f "$agent_md" ] || continue
    agent_name=$(basename "$agent_md" .md)
    fm=$(awk 'BEGIN{s=0} /^---$/{if(s==0){s=1;next} if(s==1){s=2;exit}} s==1{print}' "$agent_md")
    tools=$(
        echo "$fm" |
            sed -nE 's/^tools:[[:space:]]*(.+)$/\1/p' |
            tr ',' '\n' |
            sed -E "s/^[[:space:]'\"]+//; s/[[:space:]'\"]+$//; s/\([^)]*\)$//" |
            sed '/^$/d'
    )
    for t in $tools; do
        case "$t" in
            mcp__*|\*) continue ;;
        esac
        if ! echo " $KNOWN_TOOLS " | grep -q " $t "; then
            errors+=("[agent] $agent_name: unknown tool '$t' in tools")
            a_warn=$((a_warn + 1))
        fi
    done
done
echo "  warnings: $a_warn"

echo ""
echo "=== Summary ==="
echo "  skills OK: $pass, failed: $fail"
echo "  hooks  OK: $h_pass, failed: $h_fail"
echo "  tool warnings: $t_warn"
echo "  agent tool warnings: $a_warn"

if [ ${#errors[@]} -gt 0 ]; then
    echo ""
    echo "=== Errors ==="
    for e in "${errors[@]}"; do
        echo "  ✗ $e"
    done
    # 未知ツール（廃止 API の再混入等）も失敗扱い。warn のまま exit 0 だと CI が緑で通り抜ける
    if [ "$fail" -gt 0 ] || [ "$h_fail" -gt 0 ] || [ "$t_warn" -gt 0 ] || [ "$a_warn" -gt 0 ]; then
        exit 1
    fi
fi
exit 0
