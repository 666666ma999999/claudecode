#!/bin/bash
set -uo pipefail
# PreToolUse hook: prime_ad/tasks/m<N>-*.md の Write/Edit 時に、
# その施策の現運用突合 artifact (drift_check 生成) が存在するか確認する。
#
# - checker (m<N>_ops_check.py) が無い施策 = drift_check 対象外 → no-op (block しない)
# - checker あり・artifact 不在 → BLOCK (現運用突合せず施策を編集する事故を防ぐ)
# - checker あり・artifact 24h 超 → 警告のみ (block しない)
#
# Artifact: prime_ad/.cache/drift/M<N>[-<sub>]_<YYYY-MM-DD>.ok
# 生成: python3 -m prime_ad.scripts.sheet_sync.drift_check --all
#
# 2026-05-20: M1 ハードコード (M1 以外 no-op) を撤去し全 enabled 施策に拡張。
#             gate 対象は checker (m<N>_ops_check.py) の有無で判定する
#             (enabled:false で checker の無い施策の task 編集は block しない)。

INPUT=$(cat)
FILE_PATH=$(python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('file_path',''))" <<<"$INPUT" 2>/dev/null | tr -d '\n')

[ -z "$FILE_PATH" ] && exit 0

# prime_ad/tasks/m<N>-*.md のみ対象
case "$FILE_PATH" in
    */prime_ad/tasks/m[0-9]*.md) ;;
    *) exit 0 ;;
esac

# M 番号 (ファミリ番号) 抽出: m9-9b-execution.md → 9
M_NUM=$(basename "$FILE_PATH" | sed -nE 's/^m([0-9]+).*\.md$/\1/p')
[ -z "$M_NUM" ] && exit 0

# プロジェクトルート (prime_ad/) を遡って探す
DIR=$(dirname "$FILE_PATH")
while [ "$DIR" != "/" ] && [ "$DIR" != "" ]; do
    if [ -d "$DIR/.cache" ] || [ -d "$DIR/scripts" ]; then
        break
    fi
    DIR=$(dirname "$DIR")
done

# checker が無い施策 (drift_check 対象外) は gate しない。
# checker ファイルは常にファミリ番号: m9-9a/9b/9c はすべて m9_ops_check.py を使う。
CHECKER="$DIR/scripts/sheet_sync/m${M_NUM}_ops_check.py"
if [ ! -f "$CHECKER" ]; then
    exit 0
fi

CACHE_DIR="$DIR/.cache/drift"
# サブ番号付き artifact も拾う: M9 → M9-9b_*.ok / M9_*.ok (M19/M16 等は誤マッチしない)
ARTIFACT_GLOB="$CACHE_DIR/M${M_NUM}[-_]*.ok"

LATEST=$(ls -t $ARTIFACT_GLOB 2>/dev/null | head -1)

if [ -z "$LATEST" ]; then
    cat >&2 <<EOF
🛑 [prime-ad-drift-gate] M${M_NUM} 系の現運用突合 artifact が存在しません。
   実行: python3 -m prime_ad.scripts.sheet_sync.drift_check --all
   → prime_ad/.cache/drift/M${M_NUM}*_<date>.ok が生成され、現運用との乖離が判定されます。
   この編集は **BLOCK** されました (現運用突合せず施策を編集する事故の再発防止・PRIME_AD_AUDIT=off で一時解除可)。
EOF
    [ "${PRIME_AD_AUDIT:-on}" = "off" ] && exit 0
    exit 2
fi

# mtime チェック (24h 以内か・stale は警告のみ)
AGE_SEC=$(( $(date +%s) - $(stat -f %m "$LATEST" 2>/dev/null || stat -c %Y "$LATEST" 2>/dev/null || echo 0) ))
if [ "$AGE_SEC" -gt 86400 ]; then
    HOURS=$(( AGE_SEC / 3600 ))
    cat >&2 <<EOF
⚠️  [prime-ad-drift-gate] M${M_NUM} 系の drift artifact が古いです (${HOURS}h 前)。
   最新: $LATEST
   再実行推奨: python3 -m prime_ad.scripts.sheet_sync.drift_check --all
   (block しません)
EOF
fi

exit 0
