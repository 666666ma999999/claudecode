#!/bin/bash
# ~/.claude/hooks/sessionstart-github-issues.sh
#
# SessionStart hook: cwd repo の GitHub Open Issues を
# vault MOC `## 📋 Open Issues` セクションに mirror する (案 A-3 / 完全自動)。
#
# Feature flag:
#   ~/.claude/state/vault-cc-enabled が存在しなければ即 exit (休眠・完全無害)
#
# 設計:
#   - cwd が git repo でなければ silent skip
#   - helper script (sync-vault-summary.py issues <cwd>) に委譲
#   - helper 内で全 silent fail (gh 認証切れ / git remote 不在 / registry 未登録)
#   - 出力なし (SessionStart context を汚さず、MOC 側で結果確認する設計)
#   - gh API 呼出のため timeout 15s (settings.json 側でも指定)
#
# 関連:
#   - script: ~/.claude/scripts/sync-vault-summary.py (cmd_issues)
#   - registry: ~/Documents/Obsidian Vault/wiki/meta/project-registry.md
#   - file-placement-rules.md: repo project root §issue tracking
#
# Revert: rm ~/.claude/state/vault-cc-enabled (即休眠)

cat > /dev/null 2>&1

[ -f "$HOME/.claude/state/vault-cc-enabled" ] || exit 0

CWD="$(pwd -P 2>/dev/null)"
[ -z "$CWD" ] && exit 0

# git repo 配下かのみ判定 (非 git の vault cwd 等は silent skip)
git -C "$CWD" rev-parse --git-dir > /dev/null 2>&1 || exit 0

# helper に委譲 (全 silent fail・stdout/stderr 抑制)
python3 "$HOME/.claude/scripts/sync-vault-summary.py" issues "$CWD" 2>/dev/null >/dev/null

exit 0
