#!/bin/bash
# TaskCompleted hook: 定量的な改善を検出し /capture-improvement を提案する
# auto-skill-review.sh の後に発火。セッション中1回のみ。
#
# 検出シグナル:
#   - hooks/scripts/skills 配下の新ファイル → DX改善
#   - LOC削除 > 100行（削除 > 挿入）→ 保守堅牢性
#   - コミットメッセージに speed/optimize/reduce 等 → 各カテゴリ

set -uo pipefail

STATE_DIR="$HOME/.claude/state"
PENDING_FILE="$STATE_DIR/implementation-checklist.pending"
DONE_FILE="$STATE_DIR/improvement-capture.done"

# Consume stdin
cat > /dev/null

# Guard: already prompted this session
if [ -f "$DONE_FILE" ]; then
    exit 0
fi

# Guard: no pending checklist (no code changes)
if [ ! -f "$PENDING_FILE" ] || [ ! -s "$PENDING_FILE" ]; then
    exit 0
fi

# Parse changed files
FILE_LIST=$(tail -n +2 "$PENDING_FILE" 2>/dev/null || true)
[ -z "$FILE_LIST" ] && exit 0

# Detect improvement signals (single python3 process)
RESULT=$(python3 -c "
import sys, subprocess, os

files = [l.strip() for l in sys.stdin if l.strip()]
if not files:
    print('SKIP')
    sys.exit(0)

signals = []

# Signal 1: Infrastructure files (hooks, scripts, skills)
infra_patterns = ['hooks/', 'scripts/', 'skills/', '/hook', 'Makefile', 'Dockerfile']
infra_files = [f for f in files if any(p in f for p in infra_patterns)]
if infra_files:
    signals.append(f'dx:new_automation:{len(infra_files)}_files')

# Signal 2: LOC delta via git (deletions > insertions by 100+)
try:
    diff = subprocess.check_output(
        ['git', 'diff', '--stat', 'HEAD~5..HEAD'],
        stderr=subprocess.DEVNULL, timeout=5
    ).decode()
    lines = diff.strip().split('\n')
    if lines:
        summary = lines[-1]
        insertions = deletions = 0
        for part in summary.split(','):
            part = part.strip()
            if 'insertion' in part:
                insertions = int(part.split()[0])
            elif 'deletion' in part:
                deletions = int(part.split()[0])
        if deletions > 100 and deletions > insertions:
            signals.append(f'maintainability:loc_reduction:{deletions}_deleted')
except Exception:
    pass

# Signal 3: Improvement keywords in recent commits
try:
    log = subprocess.check_output(
        ['git', 'log', '--oneline', '-5'],
        stderr=subprocess.DEVNULL, timeout=5
    ).decode().lower()
    keywords = ['speed', 'fast', 'optimize', 'reduce', 'automate',
                'token', 'cost', 'refactor', 'simplify', 'hook', 'pipeline']
    hits = [k for k in keywords if k in log]
    if len(hits) >= 2:
        signals.append(f'keyword:{','.join(hits)}')
except Exception:
    pass

if signals:
    print('DETECTED:' + '|'.join(signals))
else:
    print('SKIP')
" 2>/dev/null)

case "$RESULT" in
    SKIP)
        exit 0
        ;;
    DETECTED:*)
        SIGNALS="${RESULT#DETECTED:}"
        mkdir -p "$STATE_DIR"
        cat <<PROMPT
IMPROVEMENT DETECTED: このセッションで定量的な改善シグナルが検出されました。
シグナル: ${SIGNALS}

X記事素材として記録する場合: /capture-improvement [改善の要約]
スキップする場合: そのまま続行してください。
PROMPT
        date '+%Y-%m-%d %H:%M:%S' > "$DONE_FILE"
        ;;
esac

exit 0
