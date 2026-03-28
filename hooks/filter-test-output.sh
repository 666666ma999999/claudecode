#!/bin/bash
# PreToolUse[Bash] hook: Filter test runner output to reduce context consumption
# Detects test commands and wraps them to show only failures (saves thousands of tokens)

INPUT=$(cat)

# Extract command from stdin JSON
COMMAND=$(echo "$INPUT" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get('command', ''))
except: pass
" 2>/dev/null)

[ -z "$COMMAND" ] && exit 0

# Detect test runner commands
IS_TEST=false
case "$COMMAND" in
    *"npm test"*|*"npm run test"*|*"npx jest"*|*"npx vitest"*)
        IS_TEST=true ;;
    *"pytest"*|*"python -m pytest"*|*"python3 -m pytest"*)
        IS_TEST=true ;;
    *"go test"*)
        IS_TEST=true ;;
    *"cargo test"*)
        IS_TEST=true ;;
    *"bundle exec rspec"*|*"rails test"*)
        IS_TEST=true ;;
    *"docker compose"*"test"*|*"docker-compose"*"test"*)
        IS_TEST=true ;;
esac

if [ "$IS_TEST" = "false" ]; then
    exit 0
fi

# Output guidance for Claude to filter test results
cat << 'EOF'
{"decision":"allow","message":"[test-filter] テスト出力が大量になる可能性があります。失敗したテストのみに注目し、成功テストの詳細は無視してください。出力が100行を超える場合は grep -E '(FAIL|ERROR|FAILED|error|✗|✘|×)' でフィルタしてください。"}
EOF
exit 0
