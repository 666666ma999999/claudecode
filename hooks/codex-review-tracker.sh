#!/bin/bash
# PostToolUse hook: mcp__codex__codex 実行時の Codex レビュー段階を追跡
# - 成功時: 2段階カウント → .done 作成
# - 失敗時 (quota等): count 増やさず、フォールバック reviewer 起動を Claude に要請

STATE_DIR="$HOME/.claude/state"
PENDING="$STATE_DIR/implementation-checklist.pending"
COUNT_FILE="$STATE_DIR/codex-review.count"
DONE="$STATE_DIR/codex-review.done"
FALLBACK_FLAG="$STATE_DIR/codex-fallback-needed"

[ -f "$PENDING" ] || exit 0
[ -f "$DONE" ] && exit 0

mkdir -p "$STATE_DIR"

# stdin は heredoc に占有されるため、INPUT を環境変数経由で Python に渡す
INPUT=$(cat)
export PENDING COUNT_FILE DONE FALLBACK_FLAG HOOK_INPUT="$INPUT"
python3 <<'PYEOF'
import json
import os
import re
import sys
from datetime import datetime
from pathlib import Path

try:
    data = json.loads(os.environ["HOOK_INPUT"])
except (json.JSONDecodeError, KeyError):
    sys.exit(0)

# Codex ツール以外は追跡不要（防御的ガード）
tool_name = data.get("tool_name", "")
if not tool_name.startswith("mcp__codex__"):
    sys.exit(0)

# tool_response を厳密に検査（誤検知を減らす）
resp = data.get("tool_response", {})
is_error = False

# 1) 明示的な is_error フィールド
if isinstance(resp, dict) and resp.get("is_error") is True:
    is_error = True

# 2) content 内のテキストでエラーパターンマッチ
if not is_error:
    text = ""
    if isinstance(resp, dict):
        content = resp.get("content", resp)
        if isinstance(content, list):
            text = " ".join(str(c.get("text", "")) for c in content if isinstance(c, dict))
        elif isinstance(content, str):
            text = content
    elif isinstance(resp, str):
        text = resp

    patterns = [
        r"quota exceeded",
        r"rate limit",
        r"authentication (error|failed|required)",
        r"\bunauthorized\b",
        r"\b401\b",
    ]
    if any(re.search(p, text.lower()) for p in patterns):
        is_error = True

pending = Path(os.environ["PENDING"])
count_file = Path(os.environ["COUNT_FILE"])
done_file = Path(os.environ["DONE"])
fallback_flag = Path(os.environ["FALLBACK_FLAG"])


def emit(msg: str) -> None:
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PostToolUse",
            "additionalContext": msg,
        }
    }))


if is_error:
    fallback_flag.touch()
    # pending ファイルから先頭5件を抽出（タイムスタンプ行を除外）
    try:
        all_lines = pending.read_text(encoding="utf-8").splitlines()
        files = [line for line in all_lines[1:] if line.strip()][:5]
        files_str = "\n".join(f"   - {f}" for f in files)
    except OSError:
        files_str = "   (pending ファイル読込失敗)"

    emit(
        '<system-reminder severity="high" action-required="codex-fallback-review">\n'
        "Codex呼び出しが失敗しました（quota/rate limit/auth等）。Codexレビューはスキップされます。\n\n"
        "フォールバック手順（次のターンで自動実行してください）:\n"
        "1. feature-dev:code-reviewer Agent を起動し、以下ファイルを仕様準拠+コード品質の2観点でレビュー:\n"
        f"{files_str}\n"
        "2. ブロッカーがあれば修正\n"
        "3. 完了したら: touch ~/.claude/state/codex-review.done\n\n"
        "これでパイプライン（auto-skill-review等）が再開します。\n"
        "</system-reminder>"
    )
    sys.exit(0)

# 正常系: カウント更新
count = 0
if count_file.exists():
    try:
        count = int(count_file.read_text(encoding="utf-8").strip())
    except ValueError:
        count = 0
count += 1
count_file.write_text(f"{count}\n", encoding="utf-8")

if count >= 2:
    done_file.write_text(f"{datetime.now():%Y-%m-%d %H:%M:%S}\n", encoding="utf-8")
    fallback_flag.unlink(missing_ok=True)
    emit(
        '<system-reminder severity="info">\n'
        "✅ Codex review Stage 2 (品質) recorded. Both stages complete. checklist解除可能。\n"
        "</system-reminder>"
    )
else:
    emit(
        '<system-reminder severity="info" action-required="codex-stage-2">\n'
        "✅ Codex review Stage 1 (仕様準拠) recorded. Stage 2 (品質レビュー) が必要です。\n"
        "</system-reminder>"
    )
PYEOF
