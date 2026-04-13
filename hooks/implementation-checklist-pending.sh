#!/bin/bash
# PostToolUse hook: Write/Edit でコードファイルを変更したらpending状態を作成
# implementation-checklist スキル実行前にユーザーへ報告することを防止する警告を出す

# stdin JSON から tool_name と file_path を取得（Claude Code公式仕様）
INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_name',''))" 2>/dev/null)
FILE_PATH=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('file_path',''))" 2>/dev/null)

# Write/Edit以外は無視
case "$TOOL_NAME" in
    Write|Edit) ;;
    *) exit 0 ;;
esac

# ファイルパスがない場合は無視
[ -z "$FILE_PATH" ] && exit 0

# ~/.claude/ 配下（memory, settings, skills, hooks, rules）は除外
case "$FILE_PATH" in
    */.claude/*) exit 0 ;;
esac

# コードファイルかどうか判定（実行コードのみ対象）
case "$FILE_PATH" in
    *.py|*.js|*.ts|*.tsx|*.jsx|*.html|*.css|*.json|*.yaml|*.yml|*.toml|*.cfg|*.ini)
        ;;
    *)
        exit 0
        ;;
esac

# state ディレクトリ確保
STATE_DIR="$HOME/.claude/state"
mkdir -p "$STATE_DIR"

PENDING_FILE="$STATE_DIR/implementation-checklist.pending"

# FEファイル編集時はブラウザ検証スタンプをクリア（再検証を強制）
case "$FILE_PATH" in
    *.html|*.css|*.scss|*.less|*.tsx|*.jsx|*/frontend/*|*/static/*|*/public/*)
        rm -f "$STATE_DIR/fe-browser-verified.done"
        ;;
esac

# pending ファイルに変更ファイルを追記（重複排除）
if [ -f "$PENDING_FILE" ]; then
    if ! grep -qF "$FILE_PATH" "$PENDING_FILE" 2>/dev/null; then
        echo "$FILE_PATH" >> "$PENDING_FILE"
    fi
else
    echo "$(date '+%Y-%m-%d %H:%M:%S')" > "$PENDING_FILE"
    echo "$FILE_PATH" >> "$PENDING_FILE"
fi

# 警告を JSON additionalContext 形式で出力（Claude の会話コンテキストに注入）
# PostToolUse の plain stdout は Claude に届かないため、hookSpecificOutput.additionalContext 必須
COUNT=$(tail -n +2 "$PENDING_FILE" 2>/dev/null | grep -cv '^[[:space:]]*$' || echo 0)
python3 <<PYEOF
import json
msg = """<system-reminder severity="high" action-required="implementation-checklist">
IMPLEMENTATION CHECKLIST PENDING (${COUNT}件蓄積)

最新変更: $FILE_PATH

ユーザーへの完了報告の前に implementation-checklist スキルを実行してください。
- STEP 1: サーバー再起動/ヘルスチェック
- STEP 2: Codexレビュー（2段階: 仕様準拠 → 品質）
- STEP 3: スキル化判断
- STEP 4: セッション記録

詳細: ~/.claude/state/implementation-checklist.pending
</system-reminder>"""
print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "PostToolUse",
        "additionalContext": msg
    }
}))
PYEOF
