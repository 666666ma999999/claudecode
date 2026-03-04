#!/bin/bash
# Git Pre-Commit Hook Template
# インストール: cp ~/.claude/hooks/git-pre-commit-template.sh <project>/.git/hooks/pre-commit
#
# ステージング済みファイルをチェックし、機密ファイルや
# シークレットのコミットをブロックする。

set -euo pipefail

RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ERRORS=0
WARNINGS=0

# =============================================
# 1. 禁止ファイルパターンチェック
# =============================================

# ブロック対象（コミット不可）
BLOCKED_PATTERNS=(
    '\.env$'
    '\.env\.'
    '\.pem$'
    '\.key$'
    '\.p12$'
    '\.pfx$'
    'id_rsa'
    'id_ed25519'
    '\.aws/credentials'
    'credentials\.csv$'
    'google-service-account\.json$'
    '\.tfvars$'
    '\.tfstate'
    '\.sqlite3$'
    '\.sqlite$'
    'dump\.sql$'
    '\.dump$'
    '\.docker/config\.json'
    '\.kube/config'
    'kubeconfig'
    '\.npmrc$'
    '\.pypirc$'
    '\.netrc$'
    'auth\.json$'
    '\.jks$'
    '\.keystore$'
)

# 警告対象（ノイズ・不要ファイル）
WARN_PATTERNS=(
    '\.DS_Store$'
    'Thumbs\.db$'
    'Desktop\.ini$'
    '\.log$'
    'node_modules/'
    '__pycache__/'
    '\.swp$'
    '\.swo$'
    'memo\.txt$'
    'scratch\.'
    '\.bak$'
    '\.old$'
)

# ステージング済みファイルを取得
STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null || true)

if [ -z "$STAGED_FILES" ]; then
    exit 0
fi

for file in $STAGED_FILES; do
    # ブロックチェック
    for pattern in "${BLOCKED_PATTERNS[@]}"; do
        if echo "$file" | grep -qE "$pattern"; then
            echo -e "${RED}[BLOCKED]${NC} $file (matches: $pattern)"
            ERRORS=$((ERRORS + 1))
        fi
    done
    # 警告チェック
    for pattern in "${WARN_PATTERNS[@]}"; do
        if echo "$file" | grep -qE "$pattern"; then
            echo -e "${YELLOW}[WARNING]${NC} $file (matches: $pattern)"
            WARNINGS=$((WARNINGS + 1))
        fi
    done
done

# =============================================
# 2. シークレットスキャン
# =============================================

SECRET_PATTERNS=(
    # AWS
    'AKIA[0-9A-Z]{16}'
    'ASIA[0-9A-Z]{16}'
    # GitHub
    'ghp_[0-9a-zA-Z]{36}'
    'github_pat_[0-9a-zA-Z_]{22,}'
    'gho_[0-9a-zA-Z]{36}'
    'ghu_[0-9a-zA-Z]{36}'
    'ghs_[0-9a-zA-Z]{36}'
    'ghr_[0-9a-zA-Z]{36}'
    # GitLab
    'glpat-[0-9a-zA-Z_-]{20,}'
    # Slack
    'xoxb-[0-9a-zA-Z-]+'
    'xoxp-[0-9a-zA-Z-]+'
    # Stripe
    'sk_live_[0-9a-zA-Z]{24,}'
    'rk_live_[0-9a-zA-Z]{24,}'
    # Google API
    'AIza[0-9A-Za-z_-]{35}'
    # OpenAI
    'sk-proj-[0-9a-zA-Z_-]{20,}'
    # 接続文字列
    'postgres://[^\s]+'
    'mongodb\+srv://[^\s]+'
    'redis://[^\s]+'
    # 秘密鍵ヘッダ
    'BEGIN.*PRIVATE KEY'
)

for file in $STAGED_FILES; do
    # バイナリファイルはスキップ
    if file "$file" 2>/dev/null | grep -q "binary"; then
        continue
    fi

    # ステージング済みの内容を検査（ワーキングツリーではなくインデックスの内容）
    CONTENT=$(git show ":$file" 2>/dev/null || true)
    if [ -z "$CONTENT" ]; then
        continue
    fi

    for pattern in "${SECRET_PATTERNS[@]}"; do
        if echo "$CONTENT" | grep -qE "$pattern"; then
            echo -e "${RED}[SECRET DETECTED]${NC} $file (matches: $pattern)"
            ERRORS=$((ERRORS + 1))
        fi
    done
done

# =============================================
# 3. 結果サマリー
# =============================================

if [ $WARNINGS -gt 0 ]; then
    echo ""
    echo -e "${YELLOW}Warnings: $WARNINGS file(s) — コミットは可能ですが確認推奨${NC}"
fi

if [ $ERRORS -gt 0 ]; then
    echo ""
    echo -e "${RED}Blocked: $ERRORS issue(s) detected — コミットを中止しました${NC}"
    echo "意図的にコミットする場合: git commit --no-verify"
    exit 1
fi

exit 0
