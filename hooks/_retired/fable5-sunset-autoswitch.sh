#!/bin/bash
# fable5-sunset-autoswitch.sh — SessionStart: 2026-07-09 以降の初回起動で
# settings.json を Fable 5 → opus + outputStyle: Fable5-like へ一度だけ切り替える。
# 依頼元: 2026-07-06 INBOX タスク（docs/fable5-sunset-runbook.md 手順の自動化・ユーザー指示）。
#
# 設計メモ（hook-development-guide 準拠）:
# - state は意図的に「マシングローバル 1 回きり」の marker。session スコープにすると
#   会話ごとに再発火してしまうため、この用途では複合キー化しないのが正しい。
# - fail-open: 解析失敗・書込失敗時は何も変更せず marker も書かない（次回起動で再試行）。
# - ユーザーが既に手動で切替済み（model が fable 系でない）なら上書きせず marker のみ置く。
# - テスト用 env 上書き: FABLE5_SWITCH_TEST_TODAY / FABLE5_SWITCH_SETTINGS / FABLE5_SWITCH_MARKER

# headless 定期実行(vault-prompt-runner)では通知が見えないため切替しない（対話セッションでのみ実行）
[ -n "$VAULT_PROMPT_RUNNER" ] && exit 0

MARKER="${FABLE5_SWITCH_MARKER:-$HOME/.claude/state/fable5-sunset-switched.done}"
[ -f "$MARKER" ] && exit 0

TODAY="${FABLE5_SWITCH_TEST_TODAY:-$(date +%Y%m%d)}"
[ "$TODAY" -ge 20260709 ] 2>/dev/null || exit 0

SETTINGS="${FABLE5_SWITCH_SETTINGS:-$HOME/.claude/settings.json}"
[ -f "$SETTINGS" ] || exit 0

python3 - "$SETTINGS" "$MARKER" <<'PY'
import json, os, shutil, sys

settings_path, marker = sys.argv[1], sys.argv[2]
try:
    with open(settings_path, encoding="utf-8") as f:
        cfg = json.load(f)
except Exception:
    sys.exit(0)  # fail-open: 読めない/壊れている settings には触らない

model = str(cfg.get("model", ""))
if not (model.startswith("claude-fable") or model.startswith("fable")):
    # 既に手動で切替済み → 設定は尊重して何も変えない。以後発火しないよう marker のみ
    with open(marker, "w", encoding="utf-8") as f:
        f.write("manual\n")
    sys.exit(0)

try:
    shutil.copy2(settings_path, settings_path + ".bak-fable5switch")
    cfg["model"] = "opus"
    cfg["outputStyle"] = "Fable5-like"
    tmp = settings_path + ".tmp-fable5switch"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(cfg, f, ensure_ascii=False, indent=2)
        f.write("\n")
    os.replace(tmp, settings_path)
except Exception:
    sys.exit(0)  # fail-open: 途中失敗なら marker を書かず次回再試行

with open(marker, "w", encoding="utf-8") as f:
    f.write("auto\n")

print("🔁 Fable5 サンセット自動切替を実行しました: model=opus / outputStyle=Fable5-like を settings.json へ書込（バックアップ: settings.json.bak-fable5switch）。新設定は次セッションから有効 — いま /clear すると即適用。切戻し手順は docs/fable5-sunset-runbook.md。")
PY
exit 0
