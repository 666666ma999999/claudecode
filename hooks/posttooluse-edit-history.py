#!/usr/bin/env -S python3 -I
# posttooluse-edit-history.py — PostToolUse hook
#
# 目的: Claude が触ったファイル (Edit/Write/MultiEdit/Read) を session 単位で記録
#       後段 userpromptsubmit-edit-recheck-warn.py が参照し、
#       「自編集ファイル言及 + Read 履歴なし」を warning として注入する。
#
# 設計理由 (wiki/meta/mistakes.md「自編集ファイルの記憶過信」再発防止 (b) 改修):
# - 自分で Write/Edit したファイルを Read せず推測回答するパターンを機械検出するため
# - jsonl は session_id + tool + file_path のみ記録 (低コスト)
#
# 旧 posttooluse-edit-history.sh (python3 を 6 回 spawn) を単一 python プロセスに置換。
# JSONL 契約・挙動を完全維持。
#
# 並行/読み手安全性 (Codex 3R P0 対応):
# - append + rotate 全体を専用ロックファイル (history + ".lock") の flock(LOCK_EX) で排他。
# - 読み手 (userpromptsubmit-edit-recheck-warn.py 等) は flock を取らないため、rotate は
#   データファイル自身を truncate せず、tmp へ書いて os.replace で atomic に差し替える。
#   これにより読み手は常に「完全な旧ファイル」か「完全な新ファイル」のいずれかしか見ない。
# - あらゆる例外・malformed 入力は握りつぶして exit 0 (fail-open・hook を絶対にブロックしない)。

import sys


def main():
    import json
    import os
    import fcntl
    import tempfile
    from datetime import datetime

    raw = sys.stdin.read()
    d = json.loads(raw)  # malformed → 例外 → 呼び出し元 except で exit 0
    if not isinstance(d, dict):
        return

    tool = d.get("tool_name", "") or ""
    ti = d.get("tool_input", {}) or {}
    if not isinstance(ti, dict):
        ti = {}
    file_path = ti.get("file_path", "") or ti.get("notebook_path", "") or ""
    session_id = d.get("session_id", "") or ""

    if not file_path:
        return

    # 旧 sh は常に文字列を書いていた。数値 session_id 等を文字列強制 (Codex 指摘の契約差異)
    tool = str(tool)
    file_path = str(file_path)
    session_id = str(session_id)

    # Edit/Write 系 vs Read 系で別ファイルに記録
    if tool in ("Edit", "Write", "MultiEdit", "NotebookEdit"):
        name = "edit-history.jsonl"
    elif tool in ("Read", "NotebookRead"):
        name = "read-history.jsonl"
    else:
        return

    state_dir = os.path.join(os.path.expanduser("~"), ".claude", "state")
    os.makedirs(state_dir, exist_ok=True)
    history_file = os.path.join(state_dir, name)
    lock_file = history_file + ".lock"

    ts = datetime.now().astimezone().isoformat(timespec="microseconds")
    # キー順 (ts, session, tool, file) と escape を旧 sh と完全一致させる
    line = '{"ts":"%s","session":%s,"tool":"%s","file":%s}\n' % (
        ts,
        json.dumps(session_id),
        tool,
        json.dumps(file_path),
    )

    # 専用ロックファイルで append + rotate 全体を排他 (データファイル自身はロックしない)
    lock_fd = os.open(lock_file, os.O_CREAT | os.O_RDWR, 0o644)
    try:
        fcntl.flock(lock_fd, fcntl.LOCK_EX)

        # append: ロック下で open→write→flush→close
        with open(history_file, "a") as f:
            f.write(line)
            f.flush()

        # rotate: 1000 行超なら直近 1000 行を atomic 差し替え (truncate せず os.replace)
        try:
            with open(history_file, "r") as f:
                lines = f.readlines()
        except FileNotFoundError:
            lines = []
        if len(lines) > 1000:
            keep = lines[-1000:]
            tmp = tempfile.NamedTemporaryFile(mode="w", dir=state_dir, delete=False)
            tmp_path = tmp.name
            try:
                tmp.writelines(keep)
                tmp.flush()
                os.fsync(tmp.fileno())
                tmp.close()
                os.replace(tmp_path, history_file)  # atomic (同一 FS)
            except Exception:
                # rotate 失敗時は tmp を掃除 (append は既に永続済みなので欠落しない)
                try:
                    tmp.close()
                except Exception:
                    pass
                try:
                    os.unlink(tmp_path)
                except Exception:
                    pass
    finally:
        try:
            fcntl.flock(lock_fd, fcntl.LOCK_UN)
        except Exception:
            pass
        os.close(lock_fd)


if __name__ == "__main__":
    try:
        main()
    except Exception:
        pass  # fail-open: hook を絶対にブロックさせない
    sys.exit(0)
