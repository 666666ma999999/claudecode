#!/usr/bin/env bash
# SessionStart hook: Claude Code バージョン変化 + MCP 健全性 (cached + background refresh)
#
# 設計: `claude --version` (3.7s) と `claude mcp list` を毎回起動で走らせていたのを改善。
#   - 起動時: 前回キャッシュ (state/version-diff.txt) を即時出力
#   - 並行: バックグラウンドで実 subprocess 実行 → キャッシュ更新

STATE_FILE="$HOME/.claude/state/claude-version.last"
CACHE="$HOME/.claude/state/version-diff.txt"
mkdir -p "$(dirname "$CACHE")"

# 1) 即時出力
[ -s "$CACHE" ] && cat "$CACHE"

# 2) バックグラウンド更新
(
  CURRENT=$(claude --version 2>/dev/null | awk '{print $1}')
  [ -z "$CURRENT" ] && exit 0

  OUTPUT=""
  if [ ! -f "$STATE_FILE" ]; then
    echo "$CURRENT" > "$STATE_FILE"
  else
    LAST=$(cat "$STATE_FILE" 2>/dev/null)
    if [ "$CURRENT" != "$LAST" ]; then
      OUTPUT="=== 📦 Claude Code バージョン変化 ===
  $LAST → $CURRENT
  公式リリース: https://github.com/anthropics/claude-code/releases/tag/v${CURRENT}
  対応: claude --help / claude auto-mode defaults で新機能確認 → 既存 hook/rule と重複あれば update-config skill で寄せ替え検討
"
      echo "$CURRENT" > "$STATE_FILE"
    fi
  fi

  MCP_ISSUES=$(claude mcp list 2>&1 | grep -v "✓ Connected" | grep -E "✗|Needs auth|failed|error" || true)
  if [ -n "$MCP_ISSUES" ]; then
    OUTPUT="${OUTPUT}=== ⚠️  MCP 接続異常 ===
${MCP_ISSUES}
  対応: \`claude mcp list\` で詳細確認 → OAuth 切れなら再認証 / 設定ミスなら ~/.claude/.mcp.json 修正
"
  fi

  printf '%s' "$OUTPUT" > "$CACHE"
) </dev/null >/dev/null 2>&1 &
disown 2>/dev/null || true

exit 0
