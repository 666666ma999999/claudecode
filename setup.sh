#!/bin/bash
# ~/.claude/setup.sh
# 新PCセットアップスクリプト - git clone後に1回実行
set -euo pipefail

CLAUDE_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Claude Code Setup ==="
echo "Directory: $CLAUDE_DIR"
echo ""

# 1. settings.local.json をテンプレートからコピー
if [ ! -f "$CLAUDE_DIR/settings.local.json" ]; then
  cp "$CLAUDE_DIR/templates/settings.local.json.example" "$CLAUDE_DIR/settings.local.json"
  echo "[OK] settings.local.json created"
else
  echo "[SKIP] settings.local.json already exists"
fi

# 2. .mcp.json をテンプレートからコピー（${HOME}展開）
if [ ! -f "$CLAUDE_DIR/.mcp.json" ]; then
  sed "s|\${HOME}|$HOME|g" "$CLAUDE_DIR/templates/mcp.json.example" > "$CLAUDE_DIR/.mcp.json"
  echo "[OK] .mcp.json created (review and update paths!)"
  echo "  → Edit ~/.claude/.mcp.json to set CODEX_PATH and other server paths"
else
  echo "[SKIP] .mcp.json already exists"
fi

# 3. シークレット確認（~/.zshrc に必要なキーが export 済みか）
REQUIRED_KEYS=(OPENAI_API_KEY)
MISSING_KEYS=()
for key in "${REQUIRED_KEYS[@]}"; do
  if ! grep -q "^export ${key}=" "$HOME/.zshrc" 2>/dev/null; then
    MISSING_KEYS+=("$key")
  fi
done
if [ ${#MISSING_KEYS[@]} -gt 0 ]; then
  echo "[WARN] ~/.zshrc に未設定のキー: ${MISSING_KEYS[*]}"
  echo "  → 手動で追記: echo 'export OPENAI_API_KEY=\"sk-...\"' >> ~/.zshrc"
else
  echo "[OK] ~/.zshrc に必須キー設定済み"
fi

# 4. memory/ ディレクトリ作成
mkdir -p "$CLAUDE_DIR/memory"
echo "[OK] memory/ directory ensured"

# 5. 全hookスクリプトに chmod +x 付与
find "$CLAUDE_DIR/hooks" -type f \( -name "*.sh" -o -name "*.py" \) -exec chmod +x {} \;
HOOK_FILES=$(find "$CLAUDE_DIR/hooks" -type f \( -name "*.sh" -o -name "*.py" \) | wc -l | tr -d ' ')
echo "[OK] hooks made executable ($HOOK_FILES files)"

# 6. スキルスクリプトにも chmod +x
find "$CLAUDE_DIR/skills" -type f -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
echo "[OK] skill scripts made executable"

echo ""
echo "=== Verification ==="

# deny数チェック
DENY_COUNT=$(python3 -c "import json; d=json.load(open('$CLAUDE_DIR/settings.json')); print(len(d.get('permissions',{}).get('deny',[])))" 2>/dev/null || echo "0")
echo "  deny rules: $DENY_COUNT"

# hooks数チェック
HOOK_COUNT=$(python3 -c "
import json
d=json.load(open('$CLAUDE_DIR/settings.json'))
hooks = d.get('hooks', {})
total = sum(len(v) for v in hooks.values())
print(total)
" 2>/dev/null || echo "0")
echo "  hooks: $HOOK_COUNT"

# settings.local.json安全性チェック
if [ -f "$CLAUDE_DIR/settings.local.json" ]; then
  HAS_HOOKS=$(python3 -c "import json; d=json.load(open('$CLAUDE_DIR/settings.local.json')); print('YES' if 'hooks' in d else 'NO')" 2>/dev/null || echo "UNKNOWN")
  echo "  settings.local.json hooks: $HAS_HOOKS (should be NO)"
fi

echo ""
echo "=== Setup Complete ==="
echo "Next steps:"
echo "  1. Edit ~/.claude/.mcp.json with your local paths"
echo "  2. ~/.zshrc に API キーを export で追記（OPENAI_API_KEY 等）"
echo "  3. source ~/.zshrc → そのターミナルから 'claude' 起動"
echo "  4. 'claude mcp list' で全 MCP が ✓ Connected か確認"
