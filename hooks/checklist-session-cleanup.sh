#!/bin/bash
# SessionStart hook: stale な implementation-checklist.pending / needs-simplify.pending を自動クリーンアップ
# 前セッションで消し忘れた pending が次セッションの Stop hook を永久ブロックするのを防ぐ
# TTL 既定 24h（CHECKLIST_TTL_HOURS / SIMPLIFY_TTL_HOURS で上書き可）

STATE_DIR="$HOME/.claude/state"
CHECKLIST_PENDING="$STATE_DIR/implementation-checklist.pending"
SIMPLIFY_PENDING="$STATE_DIR/needs-simplify.pending"

CHECKLIST_TTL_HOURS="${CHECKLIST_TTL_HOURS:-24}" \
SIMPLIFY_TTL_HOURS="${SIMPLIFY_TTL_HOURS:-24}" \
CHECKLIST_PENDING="$CHECKLIST_PENDING" \
SIMPLIFY_PENDING="$SIMPLIFY_PENDING" \
python3 <<'PYEOF' 2>/dev/null
import json
import os
import time
from datetime import datetime
from pathlib import Path

checklist_ttl = float(os.environ.get("CHECKLIST_TTL_HOURS", "24"))
simplify_ttl = float(os.environ.get("SIMPLIFY_TTL_HOURS", "24"))

checklist = Path(os.environ.get("CHECKLIST_PENDING", ""))
simplify = Path(os.environ.get("SIMPLIFY_PENDING", ""))

# checklist: mtime ベース
if checklist.exists():
    age_hours = (time.time() - checklist.stat().st_mtime) / 3600
    if age_hours > checklist_ttl:
        checklist.unlink(missing_ok=True)
        print(f"info: checklist: stale pending removed (age={age_hours:.1f}h > {checklist_ttl}h)")

# simplify: JSON の ttl_expires_at 優先、無ければ mtime
if simplify.exists():
    expired = False
    try:
        data = json.loads(simplify.read_text(encoding="utf-8"))
        ttl = data.get("ttl_expires_at", "") if isinstance(data, dict) else ""
        if ttl:
            try:
                if datetime.fromisoformat(ttl) < datetime.now():
                    expired = True
            except ValueError:
                pass
    except (OSError, json.JSONDecodeError, ValueError):
        pass
    if not expired:
        age_hours = (time.time() - simplify.stat().st_mtime) / 3600
        if age_hours > simplify_ttl:
            expired = True
    if expired:
        simplify.unlink(missing_ok=True)
        # 関連ファイルも掃除
        state_dir = simplify.parent
        (state_dir / "simplify-snapshot").unlink(missing_ok=True)
        (state_dir / "simplify-iteration").unlink(missing_ok=True)
        print(f"info: simplify: stale pending removed")
PYEOF

exit 0
