#!/bin/bash
# PreToolUse: セキュリティスキャンフック
# 機密情報の書き込みを検出・警告

# Read hook input from stdin (Claude Code hook protocol)
INPUT=$(cat)

# Extract content from JSON input
# For Write tool: content field; For Edit tool: new_string field
CONTENT=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('content',''))" 2>/dev/null)
if [ -z "$CONTENT" ]; then
    CONTENT=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('new_string',''))" 2>/dev/null)
fi

# If no content found, allow
if [ -z "$CONTENT" ]; then
    exit 0
fi

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
        cat <<HOOKEOF
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Potential secret detected matching pattern '$pattern'"}}
HOOKEOF
        exit 0
    fi
done

# 許可
exit 0
