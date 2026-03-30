#!/bin/bash
# PostToolUse[Bash] hook: 検証コマンド検出時に verify-step.pending を自動リセット
# 手動 rm の代わりに、テスト/curl等の実行で自動的にバッチカウンターをクリアする

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_name',''))" 2>/dev/null)
[ "$TOOL_NAME" != "Bash" ] && exit 0

COMMAND=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get('command', ''))
except:
    print('')
" 2>/dev/null)

STATE_DIR="$HOME/.claude/state"
PENDING_FILE="$STATE_DIR/verify-step.pending"
[ ! -f "$PENDING_FILE" ] && exit 0

IS_VERIFY=false
case "$COMMAND" in
    *pytest*|*"python -m pytest"*|*"python3 -m pytest"*)  IS_VERIFY=true ;;
    *"npm test"*|*"npm run test"*|*"npx jest"*|*"npx vitest"*)  IS_VERIFY=true ;;
    *"go test"*)  IS_VERIFY=true ;;
    *"cargo test"*)  IS_VERIFY=true ;;
    *"bundle exec rspec"*|*"rails test"*)  IS_VERIFY=true ;;
    *"docker compose"*test*|*"docker-compose"*test*)  IS_VERIFY=true ;;
    *curl*localhost*|*curl*127.0.0.1*|*curl*0.0.0.0*)  IS_VERIFY=true ;;
    *health*check*|*healthcheck*)  IS_VERIFY=true ;;
    *eslint*|*tsc*--noEmit*|*mypy*|*flake8*|*"ruff check"*)  IS_VERIFY=true ;;
esac

if [ "$IS_VERIFY" = "true" ]; then
    rm -f "$PENDING_FILE"
    echo "✅ verify-step: 検証コマンド検出。中間バッチカウンターをリセットしました。"
fi

exit 0
