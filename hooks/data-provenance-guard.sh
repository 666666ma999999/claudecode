#!/bin/bash
set -uo pipefail
# PostToolUse hook: ダッシュボード生成スクリプト変更時に data_lineage.yaml の更新有無を警告
#
# 発動条件:
#   - Write/Edit したファイルが generate_*dashboard*.py / generate_*report*.py
#   - 同プロジェクト (祖先ディレクトリ) に docs/data_lineage.yaml が存在
#
# チェック:
#   - 同セッション内で docs/data_lineage.yaml も更新されたか
#   - されていなければ警告 (block ではない)
#
# 未対応プロジェクト (data_lineage.yaml なし) では完全 no-op。

INPUT=$(cat)
FILE_PATH=$(python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('file_path',''))" <<<"$INPUT" 2>/dev/null | tr -d '\n')

[ -z "$FILE_PATH" ] && exit 0

# ~/.claude/ 配下は除外
case "$FILE_PATH" in
    */.claude/*) exit 0 ;;
esac

# ダッシュボード生成スクリプトのみ対象
case "$FILE_PATH" in
    *generate_*dashboard*.py|*generate_*report*.py) ;;
    *) exit 0 ;;
esac

# プロジェクトルート探索 (data_lineage.yaml の存在で判定)
DIR=$(dirname "$FILE_PATH")
LINEAGE=""
while [ "$DIR" != "/" ] && [ "$DIR" != "" ]; do
    if [ -f "$DIR/docs/data_lineage.yaml" ]; then
        LINEAGE="$DIR/docs/data_lineage.yaml"
        break
    fi
    DIR=$(dirname "$DIR")
done

# data_lineage.yaml が存在しないプロジェクトでは何もしない
[ -z "$LINEAGE" ] && exit 0

# 同セッション内での lineage 更新判定:
# state ファイルを使う簡易方式 (PostToolUse は前回の更新タイミングを直接知らないため)
STATE_DIR="$HOME/.claude/state"
mkdir -p "$STATE_DIR"
MARKER="$STATE_DIR/data-provenance-touched.$(echo "$LINEAGE" | python3 -c 'import sys,hashlib;print(hashlib.md5(sys.stdin.read().strip().encode()).hexdigest()[:12])')"

# yaml の最終更新が直近5分以内なら OK 扱い
if [ -f "$LINEAGE" ]; then
    YAML_MTIME=$(stat -f %m "$LINEAGE" 2>/dev/null || stat -c %Y "$LINEAGE" 2>/dev/null)
    NOW=$(date +%s)
    if [ -n "$YAML_MTIME" ] && [ $((NOW - YAML_MTIME)) -lt 300 ]; then
        # 5分以内に yaml が更新済み → OK
        exit 0
    fi
fi

# 警告 (stderr に出すと UI に表示される)
cat >&2 <<EOF
⚠ [data-provenance-guard] ダッシュボード生成スクリプトを変更しました:
  $FILE_PATH

  data_lineage.yaml の更新を確認してください:
  $LINEAGE

  新規表示の追加・既存数値の計算ロジック変更があれば yaml の displays[] を更新。
  詳細: ~/.claude/skills/data-provenance-first/references/lineage-yaml-spec.md
EOF
exit 0
