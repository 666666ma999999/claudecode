#!/bin/bash
# PreToolUse: ファイル保護フック
# 危険なファイルへの書き込みをブロック

FILE_PATH="$CLAUDE_FILE_PATH"

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
