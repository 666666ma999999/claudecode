#!/bin/bash
# PreToolUse: セキュリティスキャンフック
# 機密情報の書き込みを検出・警告

CONTENT="$CLAUDE_TOOL_INPUT"

# 機密情報パターン
SECRET_PATTERNS=(
    'AKIA[0-9A-Z]{16}'                    # AWS Access Key
    'sk-[a-zA-Z0-9]{48}'                  # OpenAI API Key
    'sk-ant-[a-zA-Z0-9-]{90,}'            # Anthropic API Key
    'ghp_[a-zA-Z0-9]{36}'                 # GitHub Personal Token
    'gho_[a-zA-Z0-9]{36}'                 # GitHub OAuth Token
    'xox[baprs]-[0-9a-zA-Z-]+'            # Slack Token
    'password\s*=\s*["\047][^"\047]+'     # Password assignment
    'api_key\s*=\s*["\047][^"\047]+'      # API Key assignment
    'secret\s*=\s*["\047][^"\047]+'       # Secret assignment
    'BEGIN (RSA |DSA |EC |OPENSSH )?PRIVATE KEY'  # Private Key
)

# パターンマッチチェック
for pattern in "${SECRET_PATTERNS[@]}"; do
    if echo "$CONTENT" | grep -qiE "$pattern"; then
        echo "{\"decision\":\"block\",\"reason\":\"Potential secret detected: pattern '$pattern'\"}"
        exit 0
    fi
done

# 許可
echo '{"decision":"approve"}'
