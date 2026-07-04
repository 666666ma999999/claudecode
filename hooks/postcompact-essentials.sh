#!/usr/bin/env bash
# SessionStart(matcher=compact) — auto-compact 直後に必須コンテキストを再注入する。
# 1) context-essentials.md: 腐らないポインタ集（進行中の事実は書かない運用）
# 2) state/compact-restore.md: PreCompact hook（precompact-build-restore-note.sh）が
#    直前に生成した作業状態メモ。mtime 30分以内のみ注入 — 古いものは別作業の
#    化石なので注入しない（2026-07-04 配管接続・鮮度ガード付き）。

set -eu

ESSENTIALS="${HOME}/.claude/context-essentials.md"
RESTORE="${HOME}/.claude/state/compact-restore.md"
RESTORE_TTL=1800  # 30分

# stdout は SessionStart hook で context に注入される
if [ -f "${ESSENTIALS}" ]; then
  echo "## [auto-compact 後 自動再注入] context-essentials.md"
  echo ""
  cat "${ESSENTIALS}"
  echo ""
fi

if [ -f "${RESTORE}" ]; then
  NOW=$(date +%s)
  MTIME=$(stat -f %m "${RESTORE}" 2>/dev/null || stat -c %Y "${RESTORE}" 2>/dev/null || echo 0)
  if [ "${MTIME}" -gt 0 ] && [ $((NOW - MTIME)) -le "${RESTORE_TTL}" ]; then
    echo "## [auto-compact 後 自動再注入] 直前の作業状態 (state/compact-restore.md)"
    echo ""
    cat "${RESTORE}"
    echo ""
  fi
fi

echo "---"
echo "_above injected by ~/.claude/hooks/postcompact-essentials.sh on $(date '+%Y-%m-%d %H:%M:%S')_"
