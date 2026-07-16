#!/usr/bin/env bash
# wiki-recall-on-prompt.sh — SessionStart hook
#
# wiki/meta/decisions.md / mistakes.md の最新 entry を
# stdout に出力して Claude の context に注入する。
#
# 設計理由 (plan.md#phase-e):
# - 過去 2 回が「rule を書いても Claude が参照しない」で失敗した。
# - SessionStart hook で物理的に prompt の前に注入することで参照を強制する。
# - 全文ではなく entry header + 短い summary に絞ってトークン節約。
#
# 2026-05-25: vault cwd guard 撤去 — repo cwd でも mistakes.md が context 注入されるよう
# (wiki/meta/mistakes.md「自編集ファイルの記憶過信」再発防止の (a) 改修)
# vault 外プロジェクトでの作業中も過去 mistake パターンを Claude が認識できる

set -u

VAULT="$HOME/Documents/Obsidian Vault"
DECISIONS="$VAULT/wiki/meta/decisions.md"
MISTAKES="$VAULT/wiki/meta/mistakes.md"

# decisions.md: ## YYYY-MM-DD entry 上位 5 個の header + 次行 (Context/Decision 等)
if [ -f "$DECISIONS" ]; then
  RECENT=$(awk '
    /^## 20[0-9]{2}-/ { cnt++; if(cnt>5) exit; if(cnt>1) print ""; print; getline; if($0 != "") print; next }
  ' "$DECISIONS" 2>/dev/null)
  if [ -n "$RECENT" ]; then
    echo "=== 📜 Recent Decisions (wiki/meta/decisions.md) ==="
    echo "$RECENT"
    echo ""
  fi
fi

# mistakes.md: ## パターン名 上位 5 個（書き方/archive セクション除外）
if [ -f "$MISTAKES" ]; then
  PATTERNS=$(awk '
    /^# / { next }
    /^## 書き方/ || /^## 例/ || /^## Archive/ { skip=1; next }
    /^## / && !skip { cnt++; if(cnt>5) exit; print }
    /^---/ { skip=0 }
  ' "$MISTAKES" 2>/dev/null)
  if [ -n "$PATTERNS" ]; then
    echo "=== ⚠️  Recurring Mistake Patterns (wiki/meta/mistakes.md) ==="
    echo "$PATTERNS"
    echo ""
    echo "(詳細は \`grep -A 6 '<pattern>' $MISTAKES\` で参照)"
  fi
fi

exit 0
