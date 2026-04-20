#!/usr/bin/env python3
"""Claude Code JSONL ログから実使用イベントだけを正しく集計するヘルパー。

禁止: grep ベースの集計（deferred_tools_delta / system-reminder の artifact を拾う）。
許可: message.content[].type == "tool_use" の name フィールドのみ集計。

Usage:
  python3 count_tool_uses.py --days 30 --type mcp
  python3 count_tool_uses.py --days 7  --type builtin
  python3 count_tool_uses.py --days 30 --type skill
  python3 count_tool_uses.py --days 30 --type edited-files
  python3 count_tool_uses.py --days 30 --type all --top 20
"""
from __future__ import annotations
import argparse, json, os, re, sys, time
from collections import Counter
from pathlib import Path

PROJECTS_DIR = Path.home() / ".claude" / "projects"


def iter_jsonl(days: int):
    cutoff = time.time() - days * 86400
    for fp in PROJECTS_DIR.rglob("*.jsonl"):
        try:
            if fp.stat().st_mtime < cutoff:
                continue
        except OSError:
            continue
        try:
            with fp.open() as f:
                for line in f:
                    try:
                        yield json.loads(line)
                    except json.JSONDecodeError:
                        continue
        except OSError:
            continue


def iter_tool_uses(days: int):
    for d in iter_jsonl(days):
        msg = d.get("message") or {}
        content = msg.get("content")
        if not isinstance(content, list):
            continue
        for item in content:
            if isinstance(item, dict) and item.get("type") == "tool_use":
                yield item


def count_mcp(days: int) -> Counter:
    c = Counter()
    for tu in iter_tool_uses(days):
        name = tu.get("name") or ""
        if name.startswith("mcp__"):
            parts = name.split("__", 2)
            if len(parts) >= 2:
                c[parts[1]] += 1
    return c


def count_builtin(days: int) -> Counter:
    c = Counter()
    for tu in iter_tool_uses(days):
        name = tu.get("name") or ""
        if name and not name.startswith("mcp__"):
            c[name] += 1
    return c


def count_skill(days: int) -> Counter:
    """<command-name>/skill-name</command-name> タグで識別"""
    pat = re.compile(r"<command-name>/?([a-zA-Z0-9_\-:]+)</command-name>")
    c = Counter()
    for d in iter_jsonl(days):
        msg = d.get("message") or {}
        content = msg.get("content")
        texts = []
        if isinstance(content, str):
            texts.append(content)
        elif isinstance(content, list):
            for item in content:
                if isinstance(item, dict) and item.get("type") == "text":
                    texts.append(item.get("text") or "")
        for t in texts:
            for m in pat.findall(t):
                c[m] += 1
    return c


def count_edited_files(days: int) -> tuple[Counter, int]:
    files = Counter()
    for tu in iter_tool_uses(days):
        name = tu.get("name") or ""
        if name not in ("Edit", "Write", "NotebookEdit"):
            continue
        inp = tu.get("input") or {}
        fp = inp.get("file_path") or inp.get("notebook_path")
        if fp:
            files[fp] += 1
    return files, len(files)


def session_count(days: int) -> int:
    sessions = set()
    for d in iter_jsonl(days):
        sid = d.get("sessionId")
        if sid:
            sessions.add(sid)
    return len(sessions)


def print_top(c: Counter, top: int):
    for name, n in c.most_common(top):
        print(f"{n:6d}  {name}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--days", type=int, default=30)
    ap.add_argument("--type", choices=["mcp", "builtin", "skill", "edited-files", "sessions", "all"], default="all")
    ap.add_argument("--top", type=int, default=30)
    args = ap.parse_args()

    if args.type in ("mcp", "all"):
        print(f"\n=== MCP usage (tool_use events, last {args.days} days) ===")
        print_top(count_mcp(args.days), args.top)

    if args.type in ("builtin", "all"):
        print(f"\n=== Built-in tools (last {args.days} days) ===")
        print_top(count_builtin(args.days), args.top)

    if args.type in ("skill", "all"):
        print(f"\n=== Skill invocations via <command-name> (last {args.days} days) ===")
        print_top(count_skill(args.days), args.top)

    if args.type in ("edited-files", "all"):
        files, uniq = count_edited_files(args.days)
        print(f"\n=== Top edited files (last {args.days} days, unique: {uniq}) ===")
        print_top(files, args.top)

    if args.type in ("sessions", "all"):
        print(f"\n=== Sessions (last {args.days} days) ===")
        print(f"{session_count(args.days):6d}  unique sessionId")


if __name__ == "__main__":
    main()
