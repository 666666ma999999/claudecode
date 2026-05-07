#!/bin/bash
# PreToolUse: ファイル保護フック (C: bash-only fast-path で Python cold start 排除)

INPUT=$(cat)

# 高速 path 抽出: jq のみ。Python フォールバック削除（cold start 1-3s 回避）
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.filePath // empty' 2>/dev/null)
[ -z "$FILE_PATH" ] && exit 0

# 早期 bail-out: 保護対象になりうる prefix/suffix キーワードをまず単一 grep で粗フィルタ
# (大半の編集はここで通過 → 28 パターンループに入らない)
case "$FILE_PATH" in
    *.env|*.env.*|*.pem|*.key|*.sqlite|*.sqlite3|*.dump|*.log|*.tfvars|*.tfstate|*.npmrc|*.pypirc|*credentials*|*secrets*|*id_rsa*|*id_ed25519*|*node_modules*|*kubeconfig*|*.kube/config|*.docker/config.json|*production*|*google-service-account.json|*npm-debug.log|*db.sql|*dump.sql|*_access_key*)
        ;;
    *)
        exit 0  # 早期通過（ホットパス）
        ;;
esac

# 詳細 deny 判定（ヒット時のみ）
PROTECTED_PATTERNS=(
    '\.env$' '\.env\.' '\.pem$' '\.key$' '/secrets/' '/credentials/' 'id_rsa' 'id_ed25519'
    '\.aws/credentials' 'config/production' 'credentials\.csv$' 'google-service-account\.json$'
    '_access_key' '\.tfvars$' '\.tfstate' '\.sqlite3$' '\.sqlite$' 'dump\.sql$' '\.dump$' 'db\.sql$'
    '/node_modules/' '\.log$' 'npm-debug\.log' '\.docker/config\.json' '\.kube/config' 'kubeconfig'
    '\.npmrc$' '\.pypirc$'
)
for pattern in "${PROTECTED_PATTERNS[@]}"; do
    if echo "$FILE_PATH" | grep -qE "$pattern"; then
        cat <<HOOKEOF
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Protected file matches pattern '$pattern': $FILE_PATH"}}
HOOKEOF
        exit 0
    fi
done
exit 0
