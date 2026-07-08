#!/bin/bash
# sessionstart-env-recall.sh — SessionStart hook（cwd=~/.claude 限定）
#
# 03_ClaudeEnv 連携ゾーン（環境ゾーン）の「懸案/NOW」を SessionStart で注入する:
#   (1) 手書き NOW 領域: ClaudeEnv_ope.md の <!-- NOW:START -->..<!-- NOW:END -->（高価値・ユーザー管理）
#   (2) drift-watch.md の P0（公式 vs 自作 リプレイス候補・自動算出）上位数件
#
# cwd=~/.claude のときだけ発火（グローバル全体のトークン増を避ける・自敵対レビュー token-roi 指摘準拠）。
# vault 不在マシンでは silent exit。
# 2026-07-06 新設（03_ClaudeEnv 昇格・plan: plans/melodic-rolling-kite.md / rules/41 環境ゾーン例外）

set -u
cat > /dev/null 2>&1   # SessionStart の stdin(JSON) を読み捨て

# --- cwd ガード: ~/.claude 配下のときだけ注入 ---
case "$PWD" in
  "$HOME/.claude"|"$HOME/.claude"/*) ;;
  *) exit 0 ;;
esac

VAULT="$HOME/Documents/Obsidian Vault"
OPE="$VAULT/03_ClaudeEnv/ClaudeEnv_ope.md"
DRIFT="$VAULT/03_ClaudeEnv/drift-watch.md"

out=""

# (1) 手書き NOW 領域（あれば最優先で注入）
if [ -f "$OPE" ]; then
  now=$(awk '/<!-- NOW:START -->/{f=1;next} /<!-- NOW:END -->/{f=0} f' "$OPE" 2>/dev/null | grep -vE '^[[:space:]]*$')
  if [ -n "$now" ]; then
    out="${out}=== 📌 環境の NOW/懸案 (手書き・03_ClaudeEnv/ClaudeEnv_ope.md) ===
${now}

"
  fi
fi

# (1.5) wiki-ingest-queue の未処理✅ 通知（1行・死蔵防止・sb2 T3）
#   ✅（- [x]）が残っている＝取り込み待ち。NOW 直後・drift 前に出す（settings 側 head -20 切断対策）。
QUEUE="$VAULT/wiki/meta/wiki-ingest-queue.md"
if [ -f "$QUEUE" ]; then
  qn=$(grep -ciE '^[[:space:]]*- \[x\]' "$QUEUE" 2>/dev/null)
  if [ "${qn:-0}" -gt 0 ] 2>/dev/null; then
    out="${out}📥 未処理✅ ${qn}件: [[wiki-ingest-queue]] を確認（「✅処理して」で wiki 化）

"
  fi
fi

# (1.7) 定期ジョブ健全性の1行注入 + 見張り自身の死活 (✅1a 見張り役の常設 2026-07-08)
#   collector-health.md「定期ジョブ健全性」節の🔴を数えて注入。無音失敗(6週間気づかず)の再発防止。
CH="$VAULT/03_ClaudeEnv/collector-health.md"
if [ -f "$CH" ]; then
  # 見張り自身の死活: daily 8:00 更新のはずが48時間超止まっていたら、見張りの停止こそを警報する
  if [ -n "$(find "$CH" -mmin +2880 2>/dev/null)" ]; then
    out="${out}🚨 見張り役(collector-health)自身が2日以上未更新 — daily 8:00 ジョブ停止の疑い（launchctl list | grep masa で確認）

"
  else
    jn=$(awk '/^## 定期ジョブ健全性/{f=1;next} /^## /{f=0} f' "$CH" 2>/dev/null | grep -c '^| 🔴')
    if [ "${jn:-0}" -gt 0 ] 2>/dev/null; then
      out="${out}🚨 定期ジョブの失敗/停滞 ${jn}件 → [[collector-health]] の「定期ジョブ健全性」節を確認

"
    fi
  fi
fi

# (2) drift-watch P0（公式追随・自作リプレイス候補・上位5件）
if [ -f "$DRIFT" ]; then
  p0=$(awk '/^## .*P0/{f=1;next} /^## .*P1/{f=0} f' "$DRIFT" 2>/dev/null | grep '^### ' | head -5)
  if [ -n "$p0" ]; then
    out="${out}=== 🚨 環境ドリフト P0 (drift-watch・公式 vs 自作) ===
${p0}
"
  fi
fi

[ -n "$out" ] && printf '%s' "$out"
exit 0
