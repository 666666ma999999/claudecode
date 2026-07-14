#!/bin/bash
# sessionstart-prompt-history-reflect.sh — SessionStart hook
# prompt-history の日次反映 (launchd でなく SessionStart 起動 = vault への TCC/FDA 問題を回避)。
# 設計: docs/prompt-history-design.md / 実行本体: scripts/prompt-history-reflect.py
# hook-development-guide 準拠: headless ガード・日次スタンプ・fail-open・出力は警告時のみ。

# headless (vault-prompt-runner 等) では実行しない
[ -n "$VAULT_PROMPT_RUNNER" ] && exit 0

# パスは env で差し替え可能 (テスト用・reflect.py と一貫)。既定は $HOME 配下
BASE="${PROMPT_HISTORY_STATE:-$HOME/.claude/state/prompt-history}"
VAULT="${PROMPT_HISTORY_VAULT:-$HOME/Documents/Obsidian Vault}"
CFG="${PROMPT_HISTORY_CONFIG:-$HOME/.claude/config/prompt-history-routing.json}"
ATTEMPT="$BASE/reflect-last-attempt"
SUCCESS="$BASE/reflect-last-success"
LOG="$BASE/reflect.log"
mkdir -p "$BASE" 2>/dev/null || exit 0

now=$(date +%s)
mtime() { stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null; }

# writer 死活の相互監視 (Codex 条件7): writer-last-success が 48h 超 or 受領票が
# 溜まっているのに一度も成功していない場合に警告
# (スタンプは vault 内 = 両 Mac に同期されるため、非 writer 機でも検知できる)
WRITER_STAMP="$VAULT/03_ClaudeEnv/prompts/.queue/writer-last-success"
if [ -f "$WRITER_STAMP" ]; then
  ws=$(mtime "$WRITER_STAMP")
  if [ -n "$ws" ] && [ $((now - ws)) -gt 172800 ]; then
    echo "⚠️ prompt-history: INBOX 反映が 48h 以上成功していません。次のどちらかを確認してください:"
    echo "   ① 「書込み役」の Mac で Claude Code を一度起動する（もう1台なら、そちらを開く）"
    echo "   ② Obsidian の Git 同期（Pull/Push）が動いているか確認する"
    echo "   詳しく見るには: tail $LOG"
  fi
else
  oldest=$(ls "$BASE/receipts" 2>/dev/null | head -1)
  if [ -n "$oldest" ]; then
    of=$(mtime "$BASE/receipts/$oldest")
    [ -n "$of" ] && [ $((now - of)) -gt 172800 ] && \
      echo "⚠️ prompt-history: 受領票が 48h 以上溜まっていますが INBOX 反映が一度も成功していません。tail $LOG で確認"
  fi
fi

# reconcile: 前回の照合結果を読み、未反映がまとまってあれば具体的に警告 (最後の砦)
RECON="$BASE/reconcile-status.json"
if [ -f "$RECON" ]; then
  /usr/bin/python3 - "$RECON" <<'PY' 2>/dev/null
import json, sys
try:
    s = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(0)
if s.get("scan_ok") is False:
    print("⚠️ prompt-history: 履歴の照合が不完全でした（読めない履歴ファイルあり）。tail ~/.claude/state/prompt-history/reflect.log で確認してください。")
un = s.get("unreflected", 0)
if un >= 20:
    miss = s.get("missing_or_renamed_inboxes") or []
    print(f"⚠️ prompt-history: 履歴 {un} 件が INBOX に反映されていません（捕捉{s.get('captured_total')}・反映{s.get('reflected_total')}）。")
    if miss:
        print(f"   原因の可能性: 次の宛先 INBOX が見つかりません（改名/移動？）: {', '.join(miss)}")
    top = list(s.get("by_route", {}).items())[:3]
    if top:
        print("   内訳: " + " / ".join(f"{k}:{v}件" for k, v in top))
    print("   ~/.claude/config/prompt-history-routing.json の宛先パスを確認してください。")
PY
fi

# writer 未設定/引き継ぎ案内: config に writer_host_uuid が無い or この機の host-uuid と不一致で
# かつ他に稼働 writer が居ない疑い (writer-last-success が古い) 時のみ、引き継ぎを案内
HOSTID_FILE="$BASE/host-uuid"
if [ -f "$CFG" ] && [ -f "$HOSTID_FILE" ]; then
  /usr/bin/python3 - "$CFG" "$HOSTID_FILE" "$WRITER_STAMP" <<'PY' 2>/dev/null
import json, os, sys, time
cfg_path, hid_path, wstamp = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    cfg = json.load(open(cfg_path))
    me = open(hid_path).read().strip()
except Exception:
    sys.exit(0)
writer = cfg.get("writer_host_uuid")
if writer == me:
    sys.exit(0)
# 稼働 writer が居るか: writer-last-success が 72h 以内なら健在とみなし案内しない
if os.path.exists(wstamp) and (time.time() - os.path.getmtime(wstamp)) < 259200:
    sys.exit(0)
if not writer:
    print("ℹ️ prompt-history: 「INBOX へ書き込む役」の Mac が未設定です。この Mac を書込み役にするなら教えてください（設定を1行直します）。")
else:
    print("ℹ️ prompt-history: 登録済みの書込み役 Mac が3日以上 INBOX を更新していません。買い替え等でこの Mac に引き継ぐなら教えてください（設定の writer を差し替えます）。")
PY
fi

# 成功 20h 未満なら skip / 成功が古くても直近 2h に試行済みなら skip (試行と成功を分離)
if [ -f "$SUCCESS" ]; then
  s=$(mtime "$SUCCESS")
  [ -n "$s" ] && [ $((now - s)) -lt 72000 ] && exit 0
fi
if [ -f "$ATTEMPT" ]; then
  a=$(mtime "$ATTEMPT")
  [ -n "$a" ] && [ $((now - a)) -lt 7200 ] && exit 0
fi
touch "$ATTEMPT"

# バックグラウンドで反映 (セッション起動をブロックしない・fail-open)
( /usr/bin/python3 "$HOME/.claude/scripts/prompt-history-reflect.py" >> "$LOG" 2>&1 ) &

exit 0
