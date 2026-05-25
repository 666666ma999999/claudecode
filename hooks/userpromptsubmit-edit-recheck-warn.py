#!/usr/bin/env python3
"""userpromptsubmit-edit-recheck-warn.py — UserPromptSubmit hook

目的: ユーザーが「自編集ファイル」について問い直してきたとき、
      Edit 後に Read していない場合 stdout で warning 注入。

検出条件 (3 つ AND):
  1. 同 session_id で Edit/Write/MultiEdit/NotebookEdit 履歴あり
  2. その Edit 後に同 file への Read 履歴なし
  3. ユーザー prompt にそのファイルパス (絶対 or basename) が含まれる

設計理由 (wiki/meta/mistakes.md「自編集ファイルの記憶過信」再発防止 (b) 改修):
- Phase 1 (a) mistakes.md 注入 + (c) CLAUDE.md ルール追記 では LLM 確率的判定で再発可能
- Phase 2 で機械検出 → stdout warning 注入で「Read してから回答」を強制
"""

import json
import os
import sys
from pathlib import Path

STATE_DIR = Path.home() / ".claude" / "state"
EDIT_LOG = STATE_DIR / "edit-history.jsonl"
READ_LOG = STATE_DIR / "read-history.jsonl"


def load_jsonl(path: Path) -> list[dict]:
    if not path.exists():
        return []
    entries = []
    with path.open() as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                entries.append(json.loads(line))
            except json.JSONDecodeError:
                continue
    return entries


def main() -> int:
    try:
        raw = sys.stdin.read()
        input_data = json.loads(raw) if raw else {}
    except (json.JSONDecodeError, ValueError):
        return 0

    session_id = input_data.get("session_id", "")
    prompt = input_data.get("prompt", "")

    if not session_id or not prompt:
        return 0

    all_edits = load_jsonl(EDIT_LOG)
    all_reads = load_jsonl(READ_LOG)

    # 同 session の edit/read のみ
    edits = [e for e in all_edits if e.get("session") == session_id]
    reads = [r for r in all_reads if r.get("session") == session_id]

    if not edits:
        return 0

    # 各 edit について、edit 後の read 有無 + prompt 言及を確認
    warnings = []
    seen_files = set()
    for e in edits:
        f = e.get("file", "")
        e_ts = e.get("ts", "")
        tool = e.get("tool", "")
        if not f or f in seen_files:
            continue
        seen_files.add(f)

        # edit 後の read を探す (timestamp 比較は文字列 ISO 8601 なので辞書順 OK)
        has_post_read = any(
            r.get("file") == f and r.get("ts", "") > e_ts for r in reads
        )
        if has_post_read:
            continue

        # ユーザー prompt にファイルパス or basename が含まれているか
        basename = os.path.basename(f)
        if f in prompt or (basename and basename in prompt):
            warnings.append((f, basename, tool))

    if warnings:
        print("【⚠️ 自編集ファイル問い直し検出 — 再 Read 必須】")
        for full, base, tool in warnings:
            print(f"  - {tool} 後 Read 履歴なし: `{base}` (full: {full})")
        print(
            "  ルール: 自編集ファイルでも `Read` で全体再確認してから回答 "
            "(ref: wiki/meta/mistakes.md「自編集ファイルの記憶過信」)"
        )

    return 0


if __name__ == "__main__":
    sys.exit(main())
