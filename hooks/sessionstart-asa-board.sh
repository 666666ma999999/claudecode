#!/bin/bash
# sessionstart-asa-board.sh — SessionStart hook: 朝ボード(asa-board.md) の再生成をトリガーする
#
# vault 03_ClaudeEnv/asa-board.md は「状態を持たない再生成ビュー」。
# 6時間キャッシュ（頻繁な再生成を避ける）・headless(vault-prompt-runner)実行では発火しない・fail-open
#（生成に失敗してもセッションはブロックしない・旧版を残す）。
# 生成本体は ~/.claude/scripts/asa-board-gen.py（Python）。
#
# 2026-07-13 新設。

set -u
cat > /dev/null 2>&1   # SessionStart の stdin(JSON) を読み捨て

# headless 実行（vault-prompt-runner 経由）では発火しない
[ -n "${VAULT_PROMPT_RUNNER:-}" ] && exit 0

VAULT="$HOME/Documents/Obsidian Vault"
BOARD="$VAULT/03_ClaudeEnv/asa-board.md"
GEN="$HOME/.claude/scripts/asa-board-gen.py"

CACHE_SECONDS=21600  # 6時間

# --- 6時間以内に生成済みなら何もしない（サイレント） ---
if [ -f "$BOARD" ]; then
  mtime=$(stat -f %m "$BOARD" 2>/dev/null || echo 0)
  now=$(date +%s)
  age=$(( now - mtime ))
  if [ "$age" -lt "$CACHE_SECONDS" ]; then
    exit 0
  fi
fi

[ -f "$GEN" ] || exit 0

# --- 10秒 timeout で生成スクリプトを実行 ---
# macOS には coreutils の `timeout` が無いことが多いため、あれば使い、無ければ perl alarm で代替する。
if command -v timeout >/dev/null 2>&1; then
  summary=$(timeout 10 python3 "$GEN" 2>/dev/null)
  rc=$?
elif command -v gtimeout >/dev/null 2>&1; then
  summary=$(gtimeout 10 python3 "$GEN" 2>/dev/null)
  rc=$?
else
  summary=$(perl -e 'alarm 10; exec @ARGV' python3 "$GEN" 2>/dev/null)
  rc=$?
fi

if [ "$rc" -ne 0 ] || [ -z "$summary" ]; then
  echo "⚠️ 朝ボード生成失敗（前回版が残っています）"
  exit 0
fi

line=$(printf '%s\n' "$summary" | grep '^SUMMARY ' | head -1)
if [ -z "$line" ]; then
  echo "⚠️ 朝ボード生成失敗（前回版が残っています）"
  exit 0
fi

# "SUMMARY 🔴2 🟡0 🟠4" -> 🔴2件 🟡0件 異常4件
red=$(printf '%s' "$line" | sed -n 's/.*🔴\([0-9][0-9]*\).*/\1/p')
yellow=$(printf '%s' "$line" | sed -n 's/.*🟡\([0-9][0-9]*\).*/\1/p')
orange=$(printf '%s' "$line" | sed -n 's/.*🟠\([0-9][0-9]*\).*/\1/p')

echo "☀️ 朝ボード更新: 🔴${red:-0}件 🟡${yellow:-0}件 異常${orange:-0}件 → [[asa-board]]"
exit 0
