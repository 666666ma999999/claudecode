#!/bin/bash
# PostToolUse[mcp__playwright__*] hook: Playwright MCP検証時に verify-step.pending を自動リセット
# FEファイル変更後のブラウザ検証を検出し、バッチカウンターをクリアする
# Bashツール経由の検証（curl, pytest等）は verify-step-auto-reset.sh が担当

STATE_DIR="$HOME/.claude/state"
PENDING_FILE="$STATE_DIR/verify-step.pending"
[ ! -f "$PENDING_FILE" ] && exit 0

# FE変更が含まれている場合のみリセット（BE-onlyの場合はPlaywrightでリセットしない）
HAS_FE=$(python3 -c "
import json
try:
    with open('$PENDING_FILE') as f:
        data = json.load(f)
    types = data.get('file_types', [])
    print('yes' if 'FE' in types else 'no')
except:
    print('no')
" 2>/dev/null)

if [ "$HAS_FE" = "yes" ]; then
    rm -f "$PENDING_FILE"
    echo "✅ verify-step: Playwright MCP検証検出。FEブラウザ検証完了、バッチカウンターをリセットしました。"
fi

exit 0
