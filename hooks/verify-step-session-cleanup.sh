#!/bin/bash
# SessionStart hook: stale な verify-step.pending を自動クリーンアップ
# クラッシュ・異常終了後の次セッションが永久ブロックされるのを防ぐ

STATE_DIR="$HOME/.claude/state"
PENDING_FILE="$STATE_DIR/verify-step.pending"

[ ! -f "$PENDING_FILE" ] && exit 0

PENDING_FILE="$PENDING_FILE" python3 -c "
import json, os
from datetime import datetime

pending_path = os.environ.get('PENDING_FILE', '')
try:
    with open(pending_path) as f:
        data = json.load(f)

    # TTL期限切れチェック
    ttl = data.get('ttl_expires_at', '')
    if ttl:
        if datetime.fromisoformat(ttl) < datetime.now():
            os.remove(pending_path)
            print('info: verify-step: stale pending removed (TTL expired).')
    else:
        # TTLフィールドなし（古い形式）→ created_at で判定（4時間超で削除）
        created = data.get('created_at', '')
        if created:
            from datetime import timedelta
            age = datetime.now() - datetime.fromisoformat(created)
            if age > timedelta(hours=4):
                os.remove(pending_path)
                print('info: verify-step: stale pending removed (older than 4 hours, no TTL).')
except Exception as e:
    # JSONパースエラー等 → 壊れたファイルを削除
    try:
        os.remove(pending_path)
        print(f'info: verify-step: corrupt pending file removed: {e}')
    except:
        pass
" 2>/dev/null

exit 0
