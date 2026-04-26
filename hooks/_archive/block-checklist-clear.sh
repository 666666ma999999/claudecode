#!/bin/bash
# PreToolUse hook (Bash): implementation-checklist.pending の解除をCodexレビュー完了まで阻止
# Codexレビュー未実行で pending ファイルを rm しようとした場合 exit 2 でブロック

INPUT=$(cat)

STATE_DIR="$HOME/.claude/state"
DONE="$STATE_DIR/codex-review.done"
PENDING="$STATE_DIR/implementation-checklist.pending"

# pending ファイルが存在しなければ保護する対象がない → 即通過
[ ! -f "$PENDING" ] && exit 0

COMMAND=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('command',''))" 2>/dev/null)

# implementation-checklist.pending を直接削除しようとするコマンドのみ検査
# 注: *">"* は 2>/dev/null 等のリダイレクションに誤マッチするため除外
case "$COMMAND" in
    *implementation-checklist.pending*)
        case "$COMMAND" in
            *rm\ *|*rm$'\t'*|*unlink*|*mv\ *|*os.remove*|*os.unlink*|*"echo "*">"*checklist*)
                ;;
            *)
                exit 0
                ;;
        esac
        ;;
    *)
        exit 0
        ;;
esac

# cwd チェック: pending が別プロジェクトのものなら Codex レビューなしで解除許可
HOOK_CWD=$(echo "$INPUT" | python3 -c "import sys,json,os; print(os.path.realpath(json.load(sys.stdin).get('cwd','')))" 2>/dev/null)
STORED_FILE=$(sed -n '2p' "$PENDING" 2>/dev/null | tr -d '[:space:]')
if [ -n "$STORED_FILE" ] && [ -n "$HOOK_CWD" ]; then
    case "$STORED_FILE" in
        "$HOOK_CWD"*) ;;  # 同一プロジェクト → 通常フローへ
        *)
            # 別プロジェクトのpending → Codexレビュー不要で解除許可
            exit 0
            ;;
    esac
fi

if [ ! -f "$DONE" ]; then
    echo "🚫 BLOCKED: implementation-checklist.pending の解除にはCodexレビュー（STEP 2）の実行が必要です。"
    echo "mcp__codex__codex で仕様準拠レビュー + コード品質レビューを実行してから再試行してください。"
    exit 2
fi

# Codexレビュー済み — 解除を許可し、追跡ファイルもクリーンアップ
rm -f "$DONE" "$STATE_DIR/codex-review.count" "$STATE_DIR/codex-fallback-needed"
exit 0
