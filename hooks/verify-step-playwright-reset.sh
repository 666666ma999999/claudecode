#!/bin/bash
# PostToolUse[mcp__playwright__*] hook: Playwright MCP検証時に verify-step.pending を自動リセット
# FEファイル変更後のブラウザ検証を検出し、バッチカウンターをクリアする
# v2: cwd スコーピング + ツール種別チェック + BE/FE分離リセット

INPUT=$(cat)

# 意味のある検証ツールのみリセット対象（screenshot単体等は除外）
TOOL_NAME=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_name',''))" 2>/dev/null)
case "$TOOL_NAME" in
    mcp__playwright__browser_navigate|mcp__playwright__browser_snapshot|mcp__playwright__browser_click|mcp__playwright__browser_console_messages)
        ;;
    *)
        exit 0
        ;;
esac

STATE_DIR="$HOME/.claude/state"
PENDING_FILE="$STATE_DIR/verify-step.pending"
[ ! -f "$PENDING_FILE" ] && exit 0

# FE変更が含まれている場合のみリセット（cwdスコープも確認）
HOOK_CWD=$(echo "$INPUT" | python3 -c "import sys,json,os; print(os.path.realpath(json.load(sys.stdin).get('cwd','')))" 2>/dev/null)

ACTION=$(PENDING_FILE="$PENDING_FILE" HOOK_CWD="$HOOK_CWD" python3 -c "
import json, os, sys, tempfile

pending_path = os.environ.get('PENDING_FILE', '')
hook_cwd = os.environ.get('HOOK_CWD', '')

try:
    with open(pending_path) as f:
        data = json.load(f)
except:
    print('skip')
    sys.exit(0)

types = data.get('file_types', [])
if 'FE' not in types:
    print('skip')
    sys.exit(0)

# cwdスコープチェック
stored_cwd = data.get('cwd', '')
if stored_cwd and hook_cwd and os.path.realpath(stored_cwd) != os.path.realpath(hook_cwd):
    print('skip')
    sys.exit(0)

# FE+BE混在の場合: FEだけリセットし、BE状態を残す
be_types = [t for t in types if t != 'FE']
if be_types:
    # BE編集も含まれている → FEのみクリア、edit_countは保持（BEの検証はcurl/test側で）
    data['file_types'] = be_types
    data['fe_verify_required'] = False
    dir_name = os.path.dirname(pending_path)
    fd, tmp = tempfile.mkstemp(dir=dir_name, suffix='.tmp')
    try:
        with os.fdopen(fd, 'w') as f:
            json.dump(data, f, indent=2)
        os.replace(tmp, pending_path)
    except:
        try: os.unlink(tmp)
        except: pass
    print('partial')
else:
    # FEのみ → 全削除
    os.remove(pending_path)
    print('full')
" 2>/dev/null)

case "$ACTION" in
    full)
        # FEブラウザ検証完了スタンプ
        date '+%Y-%m-%d %H:%M:%S' > "$STATE_DIR/fe-browser-verified.done"
        echo "✅ verify-step: Playwright MCP検証検出。FEブラウザ検証完了、バッチカウンターをリセットしました。"
        ;;
    partial)
        date '+%Y-%m-%d %H:%M:%S' > "$STATE_DIR/fe-browser-verified.done"
        echo "✅ verify-step: FEブラウザ検証完了。BE変更は未検証のため、curl/テスト実行でリセットしてください。"
        ;;
esac

exit 0
