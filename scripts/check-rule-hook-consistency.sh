#!/usr/bin/env bash
# CLAUDE.md「ユーザー手動限定」記述と hook ALLOW/明示の整合性検証 (warn-only)
# 目的: ルール変更時に hook 実装が同期されていない齟齬を SessionStart で検出する
set -o pipefail

CLAUDE_MD="$HOME/.claude/CLAUDE.md"
HOOK="$HOME/.claude/hooks/block-host-installs.py"
GUARD="$HOME/.claude/rules/10-git-and-execution-guard.md"

[ -f "$CLAUDE_MD" ] || exit 0
[ -f "$HOOK" ] || exit 0

# "ユーザー手動限定" セクション周辺の `! cmd` を抽出 (macOS bash 3.2 compat)
issues=0
while IFS= read -r cmd; do
  [ -z "$cmd" ] && continue
  key=$(echo "$cmd" | awk '{print $1, $2}')
  if ! grep -qF "$key" "$HOOK" 2>/dev/null && ! grep -qF "$key" "$GUARD" 2>/dev/null; then
    echo "[rule-hook-consistency] WARN: '$key' は CLAUDE.md で手動限定だが hook ALLOW/guard rule に明示無し" >&2
    issues=$((issues+1))
  fi
done < <(
  sed -n '/ユーザー手動限定/,/^## /p' "$CLAUDE_MD" \
    | grep -oE '`! [^`]+`' \
    | tr -d '`' \
    | sed 's/^! //' \
    | sort -u
)

if [ "$issues" -eq 0 ]; then
  echo "[rule-hook-consistency] OK: CLAUDE.md ↔ hook/guard 整合性 clean"
fi
exit 0
