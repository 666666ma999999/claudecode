#!/usr/bin/env bash
# wiki-dormant-warn.sh — SessionStart hook
#
# vault 内 cwd 時、過去 7 日間に wiki/meta/decisions.md / mistakes.md への
# 追加 commit が 0 件なら警告を出す。dormant 検知。
#
# 設計理由 (plan.md#phase-e):
# - 過去 2 回が「scaffold 完成後 1 ヶ月放置」で dwindle した。
# - 7 日間 0 commit を「運用停止 signal」として SessionStart で alert。
# - Phase 2 audit (2026-05-30) はこの hook が発火していないことを成功条件とする。

set -u

VAULT="$HOME/Documents/Obsidian Vault"

case "$PWD" in
  "$VAULT"|"$VAULT"/*) ;;
  *) exit 0 ;;
esac

[ -d "$VAULT/.git" ] || exit 0

cd "$VAULT" || exit 0

# 過去 7 日間に wiki/meta/decisions.md / mistakes.md / wiki/decisions/** への
# 追加・変更 commit を数える（merge / pre-sync snapshot のみ除外）
#
# 注意 (2026-05-23 fix): "vault backup:" は除外しない。
# 実運用では Claude/ユーザーの編集は vault backup auto-commit に吸収される。
# git log の `-- <path>` filter で当該 md を触った backup commit だけが残るので、
# 除外すると false-negative（実際に編集があっても 0 件と報告）になる。
RECENT=$(git log --since="7 days ago" --diff-filter=AM --format="%H %s" -- \
  'wiki/meta/decisions.md' \
  'wiki/meta/mistakes.md' \
  'wiki/decisions/' 2>/dev/null \
  | grep -vE "^[a-f0-9]+ (Merge|sync mirror:|pre-sync snapshot:)" \
  | wc -l | tr -d ' ')

if [ "${RECENT:-0}" -eq 0 ]; then
  echo ""
  echo "🌙 WIKI_DORMANT: 過去 7 日間 wiki/meta/decisions.md / mistakes.md への追加 commit が 0 件です。"
  echo "   vault が運用停止状態の可能性があります。"
  echo "   今セッションで重要な判断・教訓が出たら wiki/meta/decisions.md に記録してください："
  echo "   $VAULT/wiki/meta/decisions.md"
  echo ""
fi

exit 0
