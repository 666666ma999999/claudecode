#!/bin/bash
# Plan Mode hooks テストスイート
# 使い方: bash ~/.claude/tests/plan-mode/run_tests.sh
# 各テストは一時HOMEで実行（既存stateを破壊しない）

set -u

REAL_HOOKS="$HOME/.claude/hooks"
FIXTURES="$HOME/.claude/tests/plan-mode/fixtures"
PASS=0
FAIL=0
FAILED_NAMES=()

red()   { printf '\033[31m%s\033[0m' "$*"; }
green() { printf '\033[32m%s\033[0m' "$*"; }
yellow(){ printf '\033[33m%s\033[0m' "$*"; }

# 各テストで一時HOMEをセットアップ
setup_tmp_home() {
    TMP_HOME=$(mktemp -d)
    mkdir -p "$TMP_HOME/.claude/hooks"
    mkdir -p "$TMP_HOME/.claude/state"
    mkdir -p "$TMP_HOME/.claude/plans"
    # hook をコピー（本物を実行、HOME差し替えでstate分離）
    cp "$REAL_HOOKS/plan-readiness-check.sh" "$TMP_HOME/.claude/hooks/"
    cp "$REAL_HOOKS/plan-quality-check.sh" "$TMP_HOME/.claude/hooks/"
    cp "$REAL_HOOKS/plan-drift-warn.sh" "$TMP_HOME/.claude/hooks/"
    cp "$REAL_HOOKS/plan-forbidden-block.sh" "$TMP_HOME/.claude/hooks/"
    chmod +x "$TMP_HOME/.claude/hooks/"*.sh
}

teardown_tmp_home() {
    [ -n "${TMP_HOME:-}" ] && rm -rf "$TMP_HOME"
}

# run <hook> <stdin-string> → stdout を $LAST_OUT、stderr を $LAST_ERR、exit code を $LAST_CODE
# LAST_OUT は既存テスト互換のため stderr もマージ。stderr 単独検査は LAST_ERR を使用。
run_hook() {
    local hook="$1"
    local input="$2"
    local err_file
    err_file=$(mktemp)
    LAST_OUT=$(HOME="$TMP_HOME" bash "$TMP_HOME/.claude/hooks/$hook" <<<"$input" 2>"$err_file")
    LAST_CODE=$?
    LAST_ERR=$(cat "$err_file")
    LAST_OUT="${LAST_OUT}${LAST_ERR:+$'\n'}${LAST_ERR}"
    rm -f "$err_file"
}

assert_contains() {
    local name="$1" needle="$2"
    if grep -qF "$needle" <<<"$LAST_OUT"; then
        printf '  %s %s\n' "$(green PASS)" "$name"
        PASS=$((PASS+1))
    else
        printf '  %s %s (expected substring: %q)\n' "$(red FAIL)" "$name" "$needle"
        printf '    got: %q\n' "$LAST_OUT"
        FAIL=$((FAIL+1))
        FAILED_NAMES+=("$name")
    fi
}

assert_not_contains() {
    local name="$1" needle="$2"
    if grep -qF "$needle" <<<"$LAST_OUT"; then
        printf '  %s %s (unexpected substring: %q)\n' "$(red FAIL)" "$name" "$needle"
        printf '    got: %q\n' "$LAST_OUT"
        FAIL=$((FAIL+1))
        FAILED_NAMES+=("$name")
    else
        printf '  %s %s\n' "$(green PASS)" "$name"
        PASS=$((PASS+1))
    fi
}

assert_empty() {
    local name="$1"
    if [ -z "$LAST_OUT" ]; then
        printf '  %s %s\n' "$(green PASS)" "$name"
        PASS=$((PASS+1))
    else
        printf '  %s %s (expected empty, got: %q)\n' "$(red FAIL)" "$name" "$LAST_OUT"
        FAIL=$((FAIL+1))
        FAILED_NAMES+=("$name")
    fi
}

assert_code() {
    local name="$1" expected="$2"
    if [ "$LAST_CODE" = "$expected" ]; then
        printf '  %s %s\n' "$(green PASS)" "$name"
        PASS=$((PASS+1))
    else
        printf '  %s %s (expected exit %s, got %s)\n' "$(red FAIL)" "$name" "$expected" "$LAST_CODE"
        FAIL=$((FAIL+1))
        FAILED_NAMES+=("$name")
    fi
}

json_exit_plan() {
    local plan_text="$1"
    python3 -c 'import json,sys; print(json.dumps({"tool_name":"ExitPlanMode","tool_input":{"plan":sys.stdin.read()}}))' <<<"$plan_text"
}

json_enter_plan() {
    local prompt="$1"
    python3 -c 'import json,sys; print(json.dumps({"tool_name":"EnterPlanMode","tool_input":{"prompt":sys.stdin.read()}}))' <<<"$prompt"
}

json_write() {
    local path="$1"
    python3 -c 'import json,sys; print(json.dumps({"tool_name":"Write","tool_input":{"file_path":sys.argv[1]}}))' "$path"
}

# =============================================================
# R1: plan-quality-check.sh
# =============================================================
printf '\n%s\n' "$(yellow '[R1] plan-quality-check: セクション検査')"

# R1-1: 完備 MVP プラン → WARN なし
setup_tmp_home
run_hook plan-quality-check.sh "$(json_exit_plan "$(cat $FIXTURES/plan-mvp-complete.md)")"
assert_not_contains "R1-1 complete MVP plan → WARN なし" "PLAN QUALITY"
teardown_tmp_home

# R1-2: 影響範囲欠落 → WARN に "影響範囲"
setup_tmp_home
run_hook plan-quality-check.sh "$(json_exit_plan "$(cat $FIXTURES/plan-no-impact.md)")"
assert_contains "R1-2 影響範囲欠落 → WARN" "影響範囲"
teardown_tmp_home

# R1-3: 成功基準欠落 → WARN に "成功基準"
setup_tmp_home
run_hook plan-quality-check.sh "$(json_exit_plan "$(cat $FIXTURES/plan-no-success-delivery.md)")"
assert_contains "R1-3 成功基準欠落 → WARN" "成功基準"
teardown_tmp_home

# R1-4: 変更禁止ファイル欠落 → WARN に "変更禁止"
setup_tmp_home
run_hook plan-quality-check.sh "$(json_exit_plan "$(cat $FIXTURES/plan-no-forbidden.md)")"
assert_contains "R1-4 変更禁止ファイル欠落 → WARN" "変更禁止"
teardown_tmp_home

# R1-5: legacy minimal (Tasks あり → 影響範囲 OK 扱い) → 成功基準 と 変更禁止ファイル の両方 missing
setup_tmp_home
run_hook plan-quality-check.sh "$(json_exit_plan "$(cat $FIXTURES/plan-minimal-legacy.md)")"
assert_contains "R1-5 legacy → 成功基準警告" "成功基準"
assert_contains "R1-5 legacy → 変更禁止ファイル警告" "変更禁止"
teardown_tmp_home

# R1-7: 空 JSON stdin → プラン無しで静かに終了
setup_tmp_home
run_hook plan-quality-check.sh '{}'
assert_contains "R1-7 空JSON → プラン無しメッセージ" "プランファイルが見つかりません"
teardown_tmp_home

# R1-8: snapshot 抽出が 影響範囲 セクションのみから行われること
setup_tmp_home
run_hook plan-quality-check.sh "$(json_exit_plan "$(cat $FIXTURES/plan-mvp-complete.md)")"
SNAPSHOT="$TMP_HOME/.claude/state/plan-files-snapshot.txt"
if grep -qF "backend/api.py" "$SNAPSHOT" && grep -qF "frontend/widget.js" "$SNAPSHOT"; then
    printf '  %s %s\n' "$(green PASS)" "R1-8 snapshot に影響範囲パスが含まれる"
    PASS=$((PASS+1))
else
    printf '  %s %s\n' "$(red FAIL)" "R1-8 snapshot に影響範囲パスが含まれる"
    FAIL=$((FAIL+1))
    FAILED_NAMES+=("R1-8 snapshot に影響範囲パスが含まれる")
fi
if grep -qF "backend/core/engine.py" "$SNAPSHOT"; then
    printf '  %s %s\n' "$(red FAIL)" "R1-8 snapshot に変更禁止パスが含まれない"
    FAIL=$((FAIL+1))
    FAILED_NAMES+=("R1-8 snapshot に変更禁止パスが含まれない")
else
    printf '  %s %s\n' "$(green PASS)" "R1-8 snapshot に変更禁止パスが含まれない"
    PASS=$((PASS+1))
fi
teardown_tmp_home

# R1-9: forbidden 抽出が 変更禁止ファイル セクションから行われること
setup_tmp_home
run_hook plan-quality-check.sh "$(json_exit_plan "$(cat $FIXTURES/plan-mvp-complete.md)")"
FORBIDDEN_FILE="$TMP_HOME/.claude/state/plan-forbidden.txt"
if grep -qF "backend/core/engine.py" "$FORBIDDEN_FILE"; then
    printf '  %s %s\n' "$(green PASS)" "R1-9 forbidden.txt に変更禁止パスが含まれる"
    PASS=$((PASS+1))
else
    printf '  %s %s\n' "$(red FAIL)" "R1-9 forbidden.txt に変更禁止パスが含まれる"
    FAIL=$((FAIL+1))
    FAILED_NAMES+=("R1-9 forbidden.txt に変更禁止パスが含まれる")
fi
teardown_tmp_home

# =============================================================
# R4: plan-quality-check の探索パス拡張
# =============================================================
printf '\n%s\n' "$(yellow '[R4] plan-quality-check: 探索パス拡張とtool_input.plan優先')"

# R4-1: plans/ に何もないが stdin の tool_input.plan から直接検査可能
setup_tmp_home
# plans/ は空のまま
run_hook plan-quality-check.sh "$(json_exit_plan "$(cat $FIXTURES/plan-no-success-delivery.md)")"
assert_contains "R4-1 tool_input.plan 優先参照" "成功基準"
teardown_tmp_home

# R4-2: ./tasks/*.md を検出
setup_tmp_home
mkdir -p "$TMP_HOME/work/tasks"
cp "$FIXTURES/plan-no-success-delivery.md" "$TMP_HOME/work/tasks/task-001.md"
# stdin には plan を含めない、cwd はTMP_HOME/workに（cd経由）
LAST_OUT=$(cd "$TMP_HOME/work" && HOME="$TMP_HOME" bash "$TMP_HOME/.claude/hooks/plan-quality-check.sh" <<<'{"tool_name":"ExitPlanMode","tool_input":{}}' 2>&1)
LAST_CODE=$?
assert_contains "R4-2 ./tasks/*.md を検出" "成功基準"
teardown_tmp_home

# =============================================================
# R2: plan-drift-warn.sh パス末尾一致
# =============================================================
printf '\n%s\n' "$(yellow '[R2] plan-drift-warn: パス末尾一致')"

# R2-1: プラン内パスに完全一致 → WARN なし
setup_tmp_home
printf 'backend/routers/foo.py\nfrontend/widgets/bar.js\n' > "$TMP_HOME/.claude/state/plan-files-snapshot.txt"
run_hook plan-drift-warn.sh "$(json_write "/some/project/backend/routers/foo.py")"
assert_not_contains "R2-1 完全一致 → WARN なし" "PLAN DRIFT"
teardown_tmp_home

# R2-2: basenameは同じだがパス末尾が違う → WARN（偽陰性回避）
setup_tmp_home
printf 'backend/routers/foo.py\n' > "$TMP_HOME/.claude/state/plan-files-snapshot.txt"
run_hook plan-drift-warn.sh "$(json_write "/some/project/other/dir/foo.py")"
assert_contains "R2-2 basename同じでもパス末尾違えばWARN" "PLAN DRIFT"
teardown_tmp_home

# R2-3: パス末尾2セグメント一致 → WARN なし（プロジェクト違いでも許容）
setup_tmp_home
printf 'routers/foo.py\n' > "$TMP_HOME/.claude/state/plan-files-snapshot.txt"
run_hook plan-drift-warn.sh "$(json_write "/any/project/routers/foo.py")"
assert_not_contains "R2-3 末尾2セグメント一致" "PLAN DRIFT"
teardown_tmp_home

# R2-4: ~/.claude/ 配下は常に除外
setup_tmp_home
printf 'foo.py\n' > "$TMP_HOME/.claude/state/plan-files-snapshot.txt"
run_hook plan-drift-warn.sh "$(json_write "$TMP_HOME/.claude/hooks/something.py")"
assert_not_contains "R2-4 .claude配下は除外" "PLAN DRIFT"
teardown_tmp_home

# R2-5: snapshotファイルなし → WARN なし
setup_tmp_home
run_hook plan-drift-warn.sh "$(json_write "/some/random/path.py")"
assert_not_contains "R2-5 snapshot無し → skip" "PLAN DRIFT"
teardown_tmp_home

# =============================================================
# R3: plan-readiness-check.sh stamp TTL + Strategy state
# =============================================================
printf '\n%s\n' "$(yellow '[R3] plan-readiness-check: TTL + Strategy state')"

# R3-1: state 空 → WARN
setup_tmp_home
run_hook plan-readiness-check.sh "$(json_enter_plan "task please")"
assert_contains "R3-1 初回 → WARN" "PLAN READINESS"
teardown_tmp_home

# R3-2: 直後の2回目 → stamp新鮮なので skip
setup_tmp_home
run_hook plan-readiness-check.sh "$(json_enter_plan "task please")"
run_hook plan-readiness-check.sh "$(json_enter_plan "another task")"
assert_not_contains "R3-2 5分以内2回目 → skip" "PLAN READINESS"
teardown_tmp_home

# R3-3: stampが古い(>5分)→再警告
setup_tmp_home
run_hook plan-readiness-check.sh "$(json_enter_plan "task")"
# stamp の mtime を6分前に
touch -A -0600 "$TMP_HOME/.claude/state/plan-readiness.done" 2>/dev/null || \
    touch -d '6 minutes ago' "$TMP_HOME/.claude/state/plan-readiness.done" 2>/dev/null || \
    touch -t "$(date -v-6M +%Y%m%d%H%M 2>/dev/null || date -d '6 minutes ago' +%Y%m%d%H%M)" "$TMP_HOME/.claude/state/plan-readiness.done"
run_hook plan-readiness-check.sh "$(json_enter_plan "task")"
assert_contains "R3-3 TTL切れ → 再WARN" "PLAN READINESS"
teardown_tmp_home

# R3-4: plan-strategy.json あり(Delivery) → skip
setup_tmp_home
printf '{"strategy":"Delivery","selected_at":"2026-04-13T12:00:00"}' > "$TMP_HOME/.claude/state/plan-strategy.json"
run_hook plan-readiness-check.sh "$(json_enter_plan "task")"
assert_not_contains "R3-4 Strategy state あり → skip" "PLAN READINESS"
teardown_tmp_home

# =============================================================
# R5: plan-forbidden-block.sh
# =============================================================
printf '\n%s\n' "$(yellow '[R5] plan-forbidden-block: 変更禁止ファイルブロック')"

# R5-1: forbidden ファイルへの Write → exit 2 + "PLAN FORBIDDEN" メッセージ
setup_tmp_home
printf 'backend/core/engine.py\n' > "$TMP_HOME/.claude/state/plan-forbidden.txt"
run_hook plan-forbidden-block.sh "$(json_write "/some/project/backend/core/engine.py")"
assert_code "R5-1 forbidden Write → exit 2" 2
assert_contains "R5-1 forbidden Write → PLAN FORBIDDEN メッセージ" "PLAN FORBIDDEN"
teardown_tmp_home

# R5-2: forbidden 対象外への Write → exit 0 (block しない)
setup_tmp_home
printf 'backend/core/engine.py\n' > "$TMP_HOME/.claude/state/plan-forbidden.txt"
run_hook plan-forbidden-block.sh "$(json_write "/some/project/backend/service.py")"
assert_code "R5-2 非 forbidden Write → exit 0" 0
teardown_tmp_home

# R5-3: ~/.claude/ 配下への Write → exit 0 (除外)
setup_tmp_home
printf 'hooks/engine.py\n' > "$TMP_HOME/.claude/state/plan-forbidden.txt"
run_hook plan-forbidden-block.sh "$(json_write "$TMP_HOME/.claude/hooks/engine.py")"
assert_code "R5-3 .claude配下 → exit 0 (除外)" 0
teardown_tmp_home

# R5-4: forbidden ファイル空 → exit 0 (skip)
setup_tmp_home
printf '' > "$TMP_HOME/.claude/state/plan-forbidden.txt"
run_hook plan-forbidden-block.sh "$(json_write "/some/project/backend/core/engine.py")"
assert_code "R5-4 forbidden 空 → exit 0 (skip)" 0
teardown_tmp_home

# R5-5: 単一セグメント登録 (basename フォールバック) → どの階層でも block
setup_tmp_home
printf 'core_engine.py\n' > "$TMP_HOME/.claude/state/plan-forbidden.txt"
run_hook plan-forbidden-block.sh "$(json_write "/any/deep/nested/project/core_engine.py")"
assert_code "R5-5 単一セグメント登録 → basename マッチで block" 2
teardown_tmp_home

# R5-6: 単一セグメント登録 × 別 basename → block しない
setup_tmp_home
printf 'core_engine.py\n' > "$TMP_HOME/.claude/state/plan-forbidden.txt"
run_hook plan-forbidden-block.sh "$(json_write "/any/project/other_file.py")"
assert_code "R5-6 単一セグメント登録 × 別basename → 非block" 0
teardown_tmp_home

# =============================================================
# 結果サマリ
# =============================================================
printf '\n%s\n' "$(yellow '─── Summary ───')"
printf '%s: %d / %s: %d\n' "$(green PASSED)" "$PASS" "$(red FAILED)" "$FAIL"
if [ $FAIL -gt 0 ]; then
    printf '\n失敗したテスト:\n'
    for name in "${FAILED_NAMES[@]}"; do
        printf '  - %s\n' "$name"
    done
    exit 1
fi
exit 0
