#!/bin/bash
# PreToolUse: ファイル保護フック
# 危険なファイルへの書き込みをブロック
# 入力: stdin から JSON（Claude Code hooks 仕様）

INPUT=$(cat)

FILE_PATH="$(echo "$INPUT" | python3 -c "
import sys, json, os
try:
    d = json.load(sys.stdin)
    fp = d.get('tool_input', {}).get('file_path', '')
    print(os.path.realpath(fp) if fp else '')
except:
    print('')
" 2>/dev/null)"

# FILE_PATHが空の場合は対象外なので許可
if [[ -z "$FILE_PATH" ]]; then
    echo '{"decision":"approve"}'
    exit 0
fi

# 保護対象パターン（14カテゴリ・28パターン）
PROTECTED_PATTERNS=(
    # --- 既存: 環境変数・鍵 ---
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
    # --- 追加: クラウド認証 ---
    'credentials\.csv$'
    'google-service-account\.json$'
    '_access_key'
    '\.tfvars$'
    '\.tfstate'
    # --- 追加: DB ---
    '\.sqlite3$'
    '\.sqlite$'
    'dump\.sql$'
    '\.dump$'
    'db\.sql$'
    # --- 追加: 依存パッケージ ---
    '/node_modules/'
    # --- 追加: ログ ---
    '\.log$'
    'npm-debug\.log'
    # --- 追加: コンテナ/K8s認証 ---
    '\.docker/config\.json'
    '\.kube/config'
    'kubeconfig'
    # --- 追加: パッケージマネージャ認証 ---
    '\.npmrc$'
    '\.pypirc$'
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
