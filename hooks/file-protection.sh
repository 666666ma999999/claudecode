#!/bin/bash
# PreToolUse: ファイル保護フック
# 危険なファイルへの書き込みをブロック

FILE_PATH="$CLAUDE_FILE_PATH"

# 保護対象パターン
PROTECTED_PATTERNS=(
    '\.env$'
    '\.env\.'
    '\.pem$'
    '\.key$'
    '/secrets/'
    '/credentials/'
    'id_rsa'
    'id_ed25519'
    '\.aws/credentials'
    'config/production'
)

# パターンマッチチェック
for pattern in "${PROTECTED_PATTERNS[@]}"; do
    if echo "$FILE_PATH" | grep -qE "$pattern"; then
        echo "{\"decision\":\"block\",\"reason\":\"Protected file: matches pattern '$pattern'\"}"
        exit 0
    fi
done

# 許可
echo '{"decision":"approve"}'
