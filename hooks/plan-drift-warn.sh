#!/bin/bash
# PostToolUse hook: プラン外ファイルへの Write/Edit を警告
# plan-files-snapshot.txt（ExitPlanMode時に作成）に含まれないファイルへの書き込みを検知

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('file_path',''))" 2>/dev/null)

[ -z "$FILE_PATH" ] && exit 0

STATE_DIR="$HOME/.claude/state"
SNAPSHOT="$STATE_DIR/plan-files-snapshot.txt"

# スナップショットがなければスキップ（プランなし or ExitPlanMode 前）
[ ! -f "$SNAPSHOT" ] && exit 0
# スナップショットが空ならスキップ（プランにファイルパス未記載）
[ ! -s "$SNAPSHOT" ] && exit 0

# ~/.claude/ 配下は除外
case "$FILE_PATH" in
    */.claude/*) exit 0 ;;
esac

# コードファイルのみチェック
case "$FILE_PATH" in
    *.py|*.js|*.ts|*.tsx|*.jsx|*.go|*.rs|*.html|*.css) ;;
    *) exit 0 ;;
esac

# プランに含まれているか確認（フルパス or ベースネーム）
if ! grep -qF "$FILE_PATH" "$SNAPSHOT" 2>/dev/null; then
    BASENAME=$(basename "$FILE_PATH")
    if ! grep -q "$BASENAME" "$SNAPSHOT" 2>/dev/null; then
        echo "PLAN DRIFT: プラン外ファイルへの変更を検出 ($FILE_PATH)。プランの更新が必要な場合は再計画を検討してください。"
    fi
fi

exit 0
