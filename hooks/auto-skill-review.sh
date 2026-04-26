#!/bin/bash
# TaskCompleted hook: Auto skill review trigger
# Tier 1 (FULL): 3+ code / canonical / extensions → Q0-Q3
# Tier 2 (SKIP): config only / test only / style only / no code → silent
# Tier 3 (QUICK): 1-2 feature files / ambiguous → Q1 only
#
# NOTE: File extension sets here must stay in sync with:
#   - verify-step-pending.sh (FE/BE classification)
#   - implementation-checklist-pending.sh (tracked file filter)

set -euo pipefail

STATE_DIR="$HOME/.claude/state"
PENDING_FILE="$STATE_DIR/implementation-checklist.pending"
DONE_FILE="$STATE_DIR/skill-review.done"
CODEX_DONE="$STATE_DIR/codex-review.done"

# TaskCompleted は最小 JSON。stdin は消費しておく
cat > /dev/null

# Guard: 既にレビュー済み / pending なし / Codex未完了
if [ -f "$DONE_FILE" ]; then exit 0; fi
if [ ! -f "$PENDING_FILE" ] || [ ! -s "$PENDING_FILE" ]; then exit 0; fi
if [ ! -f "$CODEX_DONE" ]; then exit 0; fi

# 単一 python3 起動で分類 → Tier判定 → Scope判定 → JSON出力 まで処理
export PENDING_FILE DONE_FILE
python3 -I <<'PYEOF'
import json
import os
import sys
from datetime import datetime
from pathlib import Path

pending_file = Path(os.environ["PENDING_FILE"])
done_file = Path(os.environ["DONE_FILE"])

try:
    lines = pending_file.read_text(encoding="utf-8").splitlines()[1:]
except OSError:
    sys.exit(0)

files = [line.strip() for line in lines if line.strip()]
if not files:
    sys.exit(0)

code_exts = {".py", ".js", ".ts", ".tsx", ".jsx", ".go", ".rs", ".rb", ".java"}
config_exts = {".json", ".yaml", ".yml", ".csv", ".toml", ".cfg", ".ini", ".env"}
style_exts = {".css", ".scss", ".less"}
html_exts = {".html", ".htm"}
test_patterns = ["test_", "_test.", ".test.", ".spec.", "/tests/", "/__tests__/", "/test/"]
canonical_dirs = ["utils/", "shared/", "services/", "helpers/", "lib/", "core/"]
extension_dirs = ["extensions/"]

code_files, config_files, test_files = [], [], []
style_files, html_files = [], []
canonical_files, extension_files, feature_files = [], [], []

for f in files:
    ext = os.path.splitext(f)[1].lower()
    fl = f.lower()
    is_test = any(p in fl for p in test_patterns)
    is_canonical = any(d in f for d in canonical_dirs)
    is_extension = any(d in f for d in extension_dirs)
    is_feature = "features/" in f or "feature/" in f

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
feature_only = code_count > 0 and code_count <= 2 and all(f in feature_files for f in code_files)

# Tier determination
if test_files and code_count == 0:
    tier, reason = 2, "test_only"
elif code_count == 0 and config_files and not style_files and not html_files:
    tier, reason = 2, "config_only"
elif code_count == 0 and (style_files or html_files) and not config_files:
    tier, reason = 2, "style_html_only"
elif code_count == 0:
    tier, reason = 2, "non_code_files_only"
elif code_count >= 3 or canonical_files or extension_files:
    tier, reason = 1, "multi_code_or_canonical_or_extension"
elif feature_only:
    tier, reason = 3, "feature_files_only"
else:
    tier, reason = 3, "ambiguous"

# Q0: Scope detection
cwd = os.environ.get("PWD", os.getcwd())
claude_dir = os.path.expanduser("~/.claude")
under_cwd = under_claude = other = 0
for f in files:
    abs_f = os.path.abspath(f)
    if abs_f.startswith(claude_dir + "/"):
        under_claude += 1
    elif abs_f.startswith(cwd + "/") and os.path.abspath(cwd) != os.path.abspath(claude_dir):
        under_cwd += 1
    else:
        other += 1

total = len(files)
if under_claude > 0 and under_cwd == 0 and other == 0:
    scope = "global"
elif under_cwd == total:
    scope = "project"
elif other > 0 or (under_cwd > 0 and under_claude > 0):
    scope = "global"
else:
    scope = "ask"

scope_msg = {
    "global": "Q0判定: グローバルスキル候補（~/.claude/skills/）",
    "project": "Q0判定: プロジェクトスキル候補（.claude/skills/）",
    "ask": "Q0判定: スコープをユーザーに確認してください（グローバル or プロジェクト）",
}[scope]

# Tier 2: silent skip
if tier == 2:
    done_file.write_text(f"skip:{reason}\n", encoding="utf-8")
    sys.exit(0)


def emit(msg: str) -> None:
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "TaskCompleted",
            "additionalContext": msg,
        }
    }))


if tier == 1:
    emit(
        '<system-reminder severity="high" action-required="skill-lifecycle-review">\n'
        f"AUTO-SKILL-REVIEW (TaskCompleted): {code_count}個のコードファイルが変更されました。\n\n"
        f"{scope_msg}\n\n"
        "skill-lifecycle-referenceスキルの「スキル化判断フロー」に従い、以下を実行してください:\n\n"
        "1. 既存スキル検索: ~/.claude/skills/ と .claude/skills/ でGrep検索\n"
        "2. Q1: 新機能/新パターン/再発バグ/スキル情報の誤りに該当するか判断\n"
        "3. Q2: 今後も繰り返し使う知見か判断\n"
        "4. Q3: 既存スキルに追加可能か -> YES: 追記 / NO: ユーザー確認後に新規作成\n\n"
        "変更ファイル一覧: ~/.claude/state/implementation-checklist.pending を参照。\n"
        "</system-reminder>"
    )
elif tier == 3:
    emit(
        '<system-reminder severity="medium" action-required="q1-skill-check">\n'
        f"AUTO-SKILL-REVIEW (簡易): {code_count}個のコードファイルが変更されました。\n\n"
        "Q1チェック: この変更は新機能/新パターン/再発バグ/既存スキル情報の誤りに該当しますか？\n"
        "-> YES: skill-lifecycle-referenceスキルのQ2-Q3フローを実行してください。\n"
        "-> NO: スキル化不要。次のSTEPへ進んでください。\n"
        "</system-reminder>"
    )

done_file.write_text(f"{datetime.now():%Y-%m-%d %H:%M:%S}\n", encoding="utf-8")
PYEOF
