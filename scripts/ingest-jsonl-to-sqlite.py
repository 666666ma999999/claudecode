#!/usr/bin/env python3
"""
ingest-jsonl-to-sqlite.py — Ingest ~/.claude/projects/ + ~/.claude/archives/jsonl/ into SQLite FTS5 index.

Schema:
  messages(id, date, project, session_id, role, ts, content, tool_name, source_file)
  messages_fts(content) — FTS5 virtual table, kept in sync via triggers
  ingested_files(path, mtime) — dedup tracking

Idempotent: re-running only processes new/modified files.

Usage:
  python3 ~/.claude/scripts/ingest-jsonl-to-sqlite.py [--db PATH] [--force]
"""
import argparse
import json
import os
import sqlite3
import sys
from pathlib import Path

DEFAULT_DB = Path.home() / ".claude" / "archives" / "index.db"
SOURCES = [
    Path.home() / ".claude" / "projects",
    Path.home() / ".claude" / "archives" / "jsonl",
]

SCHEMA = """
CREATE TABLE IF NOT EXISTS messages (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    date TEXT NOT NULL,
    project TEXT NOT NULL,
    session_id TEXT,
    role TEXT NOT NULL,
    ts TEXT,
    content TEXT,
    tool_name TEXT,
    source_file TEXT,
    line_no INTEGER
);
CREATE INDEX IF NOT EXISTS idx_messages_date ON messages(date);
CREATE INDEX IF NOT EXISTS idx_messages_project ON messages(project);
CREATE INDEX IF NOT EXISTS idx_messages_tool ON messages(tool_name);
CREATE INDEX IF NOT EXISTS idx_messages_role ON messages(role);

CREATE VIRTUAL TABLE IF NOT EXISTS messages_fts
    USING fts5(content, content='messages', content_rowid='id', tokenize='unicode61');

CREATE TRIGGER IF NOT EXISTS messages_ai AFTER INSERT ON messages BEGIN
    INSERT INTO messages_fts(rowid, content) VALUES (new.id, new.content);
END;
CREATE TRIGGER IF NOT EXISTS messages_ad AFTER DELETE ON messages BEGIN
    INSERT INTO messages_fts(messages_fts, rowid, content) VALUES('delete', old.id, old.content);
END;

CREATE TABLE IF NOT EXISTS ingested_files (
    path TEXT PRIMARY KEY,
    mtime REAL NOT NULL,
    line_count INTEGER,
    ingested_at TEXT DEFAULT CURRENT_TIMESTAMP
);
"""

def extract_content(msg_content):
    """message.content が str or list-of-blocks。文字列に正規化。"""
    if isinstance(msg_content, str):
        return msg_content
    if isinstance(msg_content, list):
        parts = []
        for b in msg_content:
            if not isinstance(b, dict):
                continue
            t = b.get("type")
            if t == "text":
                parts.append(b.get("text", ""))
            elif t == "tool_use":
                # tool_use は別途tool_name列に入れるので content には代表文のみ
                name = b.get("name", "")
                parts.append(f"[tool_use:{name}]")
            elif t == "tool_result":
                tr = b.get("content", "")
                if isinstance(tr, list):
                    tr = "".join(x.get("text", "") for x in tr if isinstance(x, dict))
                parts.append(f"[tool_result]{tr[:500]}")
        return "\n".join(parts)
    return ""

def process_jsonl(db, path, project):
    """1ファイルを読み込んで INSERT。既に ingest 済みかつ mtime 変化なしならスキップ。"""
    mtime = path.stat().st_mtime
    cur = db.execute("SELECT mtime FROM ingested_files WHERE path = ?", (str(path),))
    row = cur.fetchone()
    if row and row[0] >= mtime:
        return 0, True  # skipped

    # 再取り込み時は既存行を削除
    if row:
        db.execute("DELETE FROM messages WHERE source_file = ?", (str(path),))

    inserted = 0
    with open(path, "r", encoding="utf-8") as f:
        for i, line in enumerate(f, 1):
            try:
                rec = json.loads(line)
            except json.JSONDecodeError:
                continue

            rtype = rec.get("type", "")
            if rtype not in ("user", "assistant"):
                continue

            msg = rec.get("message", {})
            role = msg.get("role", rtype)
            content_raw = msg.get("content", "")
            content = extract_content(content_raw)
            ts = rec.get("timestamp", "")
            date = ts[:10] if ts else ""
            session_id = rec.get("sessionId", "") or rec.get("session_id", "")

            # tool_use rows — 1 record per tool_use block
            tool_names = []
            if isinstance(content_raw, list):
                for b in content_raw:
                    if isinstance(b, dict) and b.get("type") == "tool_use":
                        tool_names.append(b.get("name", ""))

            if tool_names:
                for tn in tool_names:
                    db.execute(
                        "INSERT INTO messages(date, project, session_id, role, ts, content, tool_name, source_file, line_no) VALUES (?,?,?,?,?,?,?,?,?)",
                        (date, project, session_id, role, ts, content, tn, str(path), i),
                    )
                    inserted += 1
            elif content:
                db.execute(
                    "INSERT INTO messages(date, project, session_id, role, ts, content, tool_name, source_file, line_no) VALUES (?,?,?,?,?,?,?,?,?)",
                    (date, project, session_id, role, ts, content, None, str(path), i),
                )
                inserted += 1

    db.execute(
        "INSERT OR REPLACE INTO ingested_files(path, mtime, line_count) VALUES (?, ?, ?)",
        (str(path), mtime, inserted),
    )
    return inserted, False

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--db", default=str(DEFAULT_DB))
    ap.add_argument("--force", action="store_true", help="Re-ingest all files")
    args = ap.parse_args()

    db_path = Path(args.db)
    db_path.parent.mkdir(parents=True, exist_ok=True)

    db = sqlite3.connect(db_path)
    db.executescript(SCHEMA)

    if args.force:
        db.execute("DELETE FROM ingested_files")
        db.execute("DELETE FROM messages")
        db.commit()

    total_ins = 0
    total_skip = 0
    total_files = 0

    for src in SOURCES:
        if not src.is_dir():
            continue
        for path in sorted(src.glob("**/*.jsonl")):
            # プロジェクト名はパスから推定
            rel = path.relative_to(src)
            project = str(rel.parts[0]) if rel.parts else "unknown"
            try:
                ins, skipped = process_jsonl(db, path, project)
            except Exception as e:
                print(f"ERROR {path}: {e}", file=sys.stderr)
                continue
            total_files += 1
            if skipped:
                total_skip += 1
            else:
                total_ins += ins
                if ins > 0 and total_files % 50 == 0:
                    db.commit()

    db.commit()
    db.execute("INSERT INTO messages_fts(messages_fts) VALUES('optimize')")
    db.commit()
    db.close()

    print(f"ingested: {total_ins} messages from {total_files - total_skip} new/modified files")
    print(f"skipped (already up-to-date): {total_skip}")
    print(f"db: {db_path} ({db_path.stat().st_size / 1024 / 1024:.1f} MB)")

if __name__ == "__main__":
    main()
