#!/bin/bash
# PostToolUse hook: Write/Edit でコードファイルを変更したら pending 状態を作成し JSON additionalContext を返す

# hot path 高速化: bash で早期フィルタ（tool_name != Write/Edit なら python3 起動を回避）
INPUT=$(cat)
case "$INPUT" in
    *'"tool_name":"Write"'*|*'"tool_name":"Edit"'*|*'"tool_name": "Write"'*|*'"tool_name": "Edit"'*) ;;
    *) exit 0 ;;
esac

STATE_DIR="$HOME/.claude/state"
PENDING_FILE="$STATE_DIR/implementation-checklist.pending"
FE_VERIFIED="$STATE_DIR/fe-browser-verified.done"

mkdir -p "$STATE_DIR"

# 単一 python3 起動で分類判定 → pending 更新 → JSON出力 まで処理
# stdin は heredoc に占有されるため、INPUT を環境変数経由で Python に渡す（JSON injection 対策）
export PENDING_FILE FE_VERIFIED HOOK_INPUT="$INPUT"
python3 -I <<'PYEOF'
import json
import os
import sys
from datetime import datetime
from pathlib import Path

try:
    data = json.loads(os.environ["HOOK_INPUT"])
except (json.JSONDecodeError, KeyError):
    sys.exit(0)

tool_name = data.get("tool_name", "")
if tool_name not in ("Write", "Edit"):
    sys.exit(0)

file_path = data.get("tool_input", {}).get("file_path", "")
if not file_path:
    sys.exit(0)

# ~/.claude/ 配下は除外
if "/.claude/" in file_path:
    sys.exit(0)

# コードファイルのみ対象
code_exts = {".py", ".js", ".ts", ".tsx", ".jsx", ".html", ".css",
             ".json", ".yaml", ".yml", ".toml", ".cfg", ".ini"}
if Path(file_path).suffix.lower() not in code_exts:
    sys.exit(0)

# テストファイルは pending 対象外（テスト実行で別途検証されるため）
test_markers = ("/tests/", "/__tests__/", "/test/", "/spec/")
test_name_patterns = ("_test.py", "test_", ".test.ts", ".test.tsx",
                     ".test.js", ".test.jsx", ".spec.ts", ".spec.js")
fp_lower = file_path.lower()
if any(m in fp_lower for m in test_markers) or any(p in fp_lower for p in test_name_patterns):
    sys.exit(0)

# 高リスクパス判定（認証/秘密情報/外部 API）: 後の閾値ガードで例外扱い
HIGH_RISK_KEYWORDS = ("auth", "secret", "password", "token", "oauth",
                     "credential", "login", "session", "/api/", "webhook")
is_high_risk = any(kw in fp_lower for kw in HIGH_RISK_KEYWORDS)

# FEファイル編集時はブラウザ検証スタンプをクリア
fe_exts = {".html", ".css", ".scss", ".less", ".tsx", ".jsx"}
fe_dirs = ("/frontend/", "/static/", "/public/")
is_fe = Path(file_path).suffix.lower() in fe_exts or any(d in file_path for d in fe_dirs)
if is_fe:
    fe_verified = Path(os.environ["FE_VERIFIED"])
    fe_verified.unlink(missing_ok=True)

# pending 追記（重複排除）
pending = Path(os.environ["PENDING_FILE"])
if pending.exists():
    lines = pending.read_text(encoding="utf-8").splitlines()
    if file_path not in lines:
        with pending.open("a", encoding="utf-8") as f:
            f.write(file_path + "\n")
    # 既存ファイルでも mtime を更新（TTL のローリング更新のため）
    os.utime(pending, None)
else:
    pending.write_text(
        f"{datetime.now():%Y-%m-%d %H:%M:%S}\n{file_path}\n",
        encoding="utf-8",
    )
    # NOTE: 旧仕様では新規 pending 作成のたびに codex-review.count/done を
    # リセットしていたが、バッチ毎にフル 2 段レビューが再走してトークンを消費する
    # 主因となっていたため停止（2026-05-01 reduce-review-token タスク）。
    # 同一 diff 内の連続編集では Codex 完了状態を保持する。

# 件数カウント（先頭のタイムスタンプ行を除外）
all_lines = pending.read_text(encoding="utf-8").splitlines()
count = sum(1 for line in all_lines[1:] if line.strip())

# 高リスクパスを含む変更があれば flag を立てる（stop hook の閾値ガードで参照）
high_risk_flag = pending.parent / "checklist-high-risk.flag"
if is_high_risk:
    high_risk_flag.touch()

# json.dumps で自動エスケープ（ファイルパスに " や \ が含まれても安全）
msg = (
    '<system-reminder severity="high" action-required="implementation-checklist">\n'
    f"IMPLEMENTATION CHECKLIST PENDING ({count}件蓄積)\n\n"
    f"最新変更: {file_path}\n\n"
    "ユーザーへの完了報告の前に implementation-checklist スキルを実行してください。\n"
    "- STEP 1: サーバー再起動/ヘルスチェック\n"
    "- STEP 2: Codexレビュー（1段統合: 仕様準拠+品質）\n"
    "- STEP 3: スキル化判断\n"
    "- STEP 4: セッション記録\n\n"
    "詳細: ~/.claude/state/implementation-checklist.pending\n"
    "</system-reminder>"
)
print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "PostToolUse",
        "additionalContext": msg,
    }
}))
PYEOF
