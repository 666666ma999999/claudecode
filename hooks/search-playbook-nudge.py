#!/usr/bin/env python3
"""PreToolUse hook: 検索系ツールの初回呼び出し時だけ search-playbook を引くよう想起注入する。
ブロックしない・セッション1回のみ・失敗時も fail-open（検索を邪魔しない）。2026-07-22 敵対レビュー2R 確定。"""
import sys, os, json, hashlib

def main():
    try:
        raw = sys.stdin.read()
        data = json.loads(raw) if raw.strip() else {}
    except Exception:
        sys.exit(0)  # 解析不能でも検索は通す

    session_id = str(data.get("session_id") or "").strip()
    if not session_id:
        sys.exit(0)  # headless 等はスキップ

    # セッション1回のみ（重複注入=儀式化を防ぐ）
    state_dir = os.path.expanduser("~/.claude/state/search-nudge")
    try:
        os.makedirs(state_dir, exist_ok=True)
        key = hashlib.sha1(session_id.encode("utf-8")).hexdigest()[:16]
        marker = os.path.join(state_dir, key)
        if os.path.exists(marker):
            sys.exit(0)
        with open(marker, "w") as f:
            f.write(session_id)
    except Exception:
        sys.exit(0)  # state 書けなくても検索は通す

    msg = (
        "🔎 検索の前に: vault `02_Ai/search-playbook.md`（検索攻略ノート）§2 で "
        "このドメインの勝ちパターン・内部索引(図鑑/radar)を先に確認。"
        "対象案件（繰り返す検索・お金/健康など重い判断・外れた時・新パターンの芽）なら、"
        "検索後に §4-B の固定書式で1行ログを書き戻す（軽い事実確認は不要）。"
    )
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "additionalContext": msg
        }
    }))
    sys.exit(0)

if __name__ == "__main__":
    main()
