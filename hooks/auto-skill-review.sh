#!/bin/bash
# TaskCompleted hook: Auto skill review trigger
# Reads implementation-checklist.pending to classify changes
# and prompt Claude for skill creation/update when appropriate.
#
# Tier 1 (FULL): 3+ code files / canonical module / extensions layer → Q0-Q3
# Tier 2 (SKIP): config only / test only / style only / no code → silent
# Tier 3 (QUICK): 1-2 feature files / ambiguous → Q1 only
#
# NOTE: File extension sets here must stay in sync with:
#   - verify-step-pending.sh (FE/BE classification)
#   - implementation-checklist-pending.sh (tracked file filter)

set -euo pipefail

# --- Constants ---
STATE_DIR="$HOME/.claude/state"
PENDING_FILE="$STATE_DIR/implementation-checklist.pending"
DONE_FILE="$STATE_DIR/skill-review.done"

# --- Consume stdin (TaskCompleted provides minimal JSON) ---
cat > /dev/null

# --- Guard: already reviewed ---
if [ -f "$DONE_FILE" ]; then
    exit 0
fi

# --- Guard: no pending checklist ---
if [ ! -f "$PENDING_FILE" ] || [ ! -s "$PENDING_FILE" ]; then
    exit 0
fi

# --- Guard: Codex review not yet completed ---
# スキルレビューはCodexレビュー（STEP 2）完了後に実行すべき
CODEX_DONE="$STATE_DIR/codex-review.done"
if [ ! -f "$CODEX_DONE" ]; then
    # Codex未完了 → スキルレビューを保留（次回TaskCompletedで再評価）
    exit 0
fi

# --- Parse file list (Line 1 = timestamp, Lines 2+ = file paths) ---
FILE_LIST=$(tail -n +2 "$PENDING_FILE" 2>/dev/null || true)
if [ -z "$FILE_LIST" ]; then
    exit 0
fi

# --- Classify files, determine tier, and detect scope (single python3 process) ---
RESULT=$(echo "$FILE_LIST" | python3 -c "
import sys, os

files = [line.strip() for line in sys.stdin if line.strip()]
if not files:
    print('TIER=2')
    print('CODE_COUNT=0')
    print('REASON=no_files')
    print('SCOPE=ask')
    sys.exit(0)

code_exts = {'.py', '.js', '.ts', '.tsx', '.jsx', '.go', '.rs', '.rb', '.java'}
config_exts = {'.json', '.yaml', '.yml', '.csv', '.toml', '.cfg', '.ini', '.env'}
style_exts = {'.css', '.scss', '.less'}
html_exts = {'.html', '.htm'}
test_patterns = ['test_', '_test.', '.test.', '.spec.', '/tests/', '/__tests__/', '/test/']
canonical_dirs = ['utils/', 'shared/', 'services/', 'helpers/', 'lib/', 'core/']
extension_dirs = ['extensions/']

code_files = []
config_files = []
test_files = []
style_files = []
html_files = []
canonical_files = []
extension_files = []
feature_files = []

for f in files:
    ext = os.path.splitext(f)[1].lower()
    is_test = any(p in f.lower() for p in test_patterns)
    is_canonical = any(d in f for d in canonical_dirs)
    is_extension = any(d in f for d in extension_dirs)
    is_feature = 'features/' in f or 'feature/' in f

    if is_test:
        test_files.append(f)
    elif ext in code_exts:
        code_files.append(f)
        if is_canonical:
            canonical_files.append(f)
        if is_extension:
            extension_files.append(f)
        if is_feature:
            feature_files.append(f)
    elif ext in config_exts:
        config_files.append(f)
    elif ext in style_exts:
        style_files.append(f)
    elif ext in html_exts:
        html_files.append(f)

code_count = len(code_files)
canonical_count = len(canonical_files)
extension_count = len(extension_files)
feature_only = (code_count > 0 and code_count <= 2
                and all(f in feature_files for f in code_files))

# Tier determination (order matters: specific before general)
if len(test_files) > 0 and code_count == 0:
    tier, reason = 2, 'test_only'
elif code_count == 0 and len(config_files) > 0 and len(style_files) == 0 and len(html_files) == 0:
    tier, reason = 2, 'config_only'
elif code_count == 0 and (len(style_files) + len(html_files)) > 0 and len(config_files) == 0:
    tier, reason = 2, 'style_html_only'
elif code_count == 0:
    tier, reason = 2, 'non_code_files_only'
elif code_count >= 3 or canonical_count > 0 or extension_count > 0:
    tier, reason = 1, 'multi_code_or_canonical_or_extension'
elif feature_only:
    tier, reason = 3, 'feature_files_only'
else:
    tier, reason = 3, 'ambiguous'

# Q0: Scope detection (Global vs Project)
cwd = os.environ.get('PWD', os.getcwd())
claude_dir = os.path.expanduser('~/.claude')
under_cwd = 0
under_claude = 0
other = 0

for f in files:
    abs_f = os.path.abspath(f)
    if abs_f.startswith(claude_dir + '/'):
        under_claude += 1
    elif abs_f.startswith(cwd + '/') and os.path.abspath(cwd) != os.path.abspath(claude_dir):
        under_cwd += 1
    else:
        other += 1

total = len(files)
if total == 0:
    scope = 'ask'
elif under_claude > 0 and under_cwd == 0 and other == 0:
    scope = 'global'
elif under_cwd == total:
    scope = 'project'
elif other > 0 or (under_cwd > 0 and under_claude > 0):
    scope = 'global'
else:
    scope = 'ask'

print(f'TIER={tier}')
print(f'CODE_COUNT={code_count}')
print(f'REASON={reason}')
print(f'SCOPE={scope}')
" 2>/dev/null)

# --- Parse results (zero subprocesses) ---
TIER="" CODE_COUNT="" REASON="" SCOPE=""
while IFS='=' read -r key val; do
    case "$key" in
        TIER)       TIER="$val" ;;
        CODE_COUNT) CODE_COUNT="$val" ;;
        REASON)     REASON="$val" ;;
        SCOPE)      SCOPE="$val" ;;
    esac
done <<< "$RESULT"

# Default on parse failure
[ -z "$TIER" ] && TIER=2
[ -z "$SCOPE" ] && SCOPE="ask"

# --- Tier 2: Silent skip ---
if [ "$TIER" -eq 2 ] 2>/dev/null; then
    echo "skip:${REASON}" > "$DONE_FILE"
    exit 0
fi

# --- Build scope message ---
case "$SCOPE" in
    global)  SCOPE_MSG="Q0判定: グローバルスキル候補（~/.claude/skills/）" ;;
    project) SCOPE_MSG="Q0判定: プロジェクトスキル候補（.claude/skills/）" ;;
    ask)     SCOPE_MSG="Q0判定: スコープをユーザーに確認してください（グローバル or プロジェクト）" ;;
esac

# --- Emit prompt based on tier ---
if [ "$TIER" -eq 1 ]; then
    cat <<PROMPT
AUTO-SKILL-REVIEW (TaskCompleted): ${CODE_COUNT}個のコードファイルが変更されました。

${SCOPE_MSG}

skill-lifecycle-referenceスキルの「スキル化判断フロー」に従い、以下を実行してください:

1. 既存スキル検索: ~/.claude/skills/ と .claude/skills/ でGrep検索
2. Q1: 新機能/新パターン/再発バグ/スキル情報の誤りに該当するか判断
3. Q2: 今後も繰り返し使う知見か判断
4. Q3: 既存スキルに追加可能か -> YES: 追記 / NO: ユーザー確認後に新規作成

変更ファイル一覧: ~/.claude/state/implementation-checklist.pending を参照。
PROMPT

elif [ "$TIER" -eq 3 ]; then
    cat <<PROMPT
AUTO-SKILL-REVIEW (簡易): ${CODE_COUNT}個のコードファイルが変更されました。

Q1チェック: この変更は新機能/新パターン/再発バグ/既存スキル情報の誤りに該当しますか？
-> YES: skill-lifecycle-referenceスキルのQ2-Q3フローを実行してください。
-> NO: スキル化不要。次のSTEPへ進んでください。
PROMPT
fi

# --- Mark as done ---
date '+%Y-%m-%d %H:%M:%S' > "$DONE_FILE"

exit 0
