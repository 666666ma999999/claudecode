#!/usr/bin/env python3
"""
Bridge from 03_ClaudeEnv/drift-watch.md to make_article queue.

- Parses drift-watch.md for blocks with `article_candidate: yes` and empty `posted_from:`
- Writes each as a brief markdown into ~/Desktop/biz/make_article/data/claudeenv_queue/
- Idempotent via url-hash filename

Usage: python3 article_bridge.py [--dry-run]
"""

import argparse
import hashlib
import re
import sys
from datetime import datetime
from pathlib import Path

HOME = Path.home()
VAULT = HOME / "Documents/Obsidian Vault"
DRIFT = VAULT / "03_ClaudeEnv/drift-watch.md"
MAKE_ARTICLE_QUEUE = HOME / "Desktop/biz/make_article/data/claudeenv_queue"


def check_material_bank_health(vault: Path, stale_days: int = 30, thin_threshold: int = 20) -> dict:
    """Check material-bank collection recency and volume.

    Returns dict with keys: is_stale, is_thin, last_date, count, warning
    warning is "stale_or_thin" if either condition met, else "ok"
    """
    raw_dir = vault / ".raw"
    files = sorted(raw_dir.glob("material-bank-*.jsonl")) if raw_dir.exists() else []

    if not files:
        return {"is_stale": True, "is_thin": True, "last_date": "never", "count": 0, "warning": "stale_or_thin"}

    latest = files[-1]
    mtime = datetime.fromtimestamp(latest.stat().st_mtime)
    age_days = (datetime.now() - mtime).days
    is_stale = age_days > stale_days

    count = 0
    for f in files:
        try:
            count += sum(1 for line in f.read_text(encoding="utf-8").splitlines() if line.strip())
        except Exception:
            pass
    is_thin = count < thin_threshold

    warning = "stale_or_thin" if (is_stale or is_thin) else "ok"
    return {
        "is_stale": is_stale,
        "is_thin": is_thin,
        "last_date": mtime.strftime("%Y-%m-%d"),
        "age_days": age_days,
        "count": count,
        "warning": warning,
    }


def parse_drift_blocks(text: str) -> list[dict]:
    """Parse `### [title](url)` blocks with metadata lines."""
    blocks = []
    cur = None
    for line in text.splitlines():
        m = re.match(r"^### \[(?P<title>.+?)\]\((?P<url>https?://[^)]+)\)\s*$", line)
        if m:
            if cur:
                blocks.append(cur)
            cur = {"title": m.group("title"), "url": m.group("url")}
            continue
        if cur is None:
            continue
        m = re.match(r"^- \*\*(\w+(?:_\w+)?)\*\*:\s*(.+)$", line)
        if m:
            cur[m.group(1)] = m.group(2).strip()
    if cur:
        blocks.append(cur)
    return blocks


def url_hash(url: str) -> str:
    return hashlib.sha256(url.encode()).hexdigest()[:12]


def write_queue_item(block: dict, queue_dir: Path, material_warning: str = "ok") -> Path:
    h = url_hash(block["url"])
    out = queue_dir / f"claudeenv-{h}.md"
    if out.exists():
        return out  # already queued
    content = f"""---
source: claude-env-drift-watch
url: {block['url']}
title: {block['title']}
priority: P0
queued_at: {Path(__file__).name}
material_warning: {material_warning}
---

# {block['title']}

**Source URL**: {block['url']}

**Why now**: Claude Code / Anthropic 公式の P0 更新。自環境への影響あり。

**Stance**: 中立解説 + 自運用の文脈

**Article candidate from**: `03_ClaudeEnv/drift-watch.md`

**Status**: queued (未執筆)

## 元情報
- source: {block.get('source', '?')}
- date: {block.get('date', '?')}
- matched_skills: {block.get('matched_skills', '—')}

## 執筆メモ
(make_article プロジェクトで `/generate-x-post` または `/generate-x-article` に渡す)
"""
    out.write_text(content, encoding="utf-8")
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    if not DRIFT.exists():
        print(f"[article_bridge] {DRIFT} not found", file=sys.stderr)
        return 1

    blocks = parse_drift_blocks(DRIFT.read_text(encoding="utf-8"))
    UNPOSTED_MARKERS = {"", "(未投稿)", "—"}
    candidates = [
        b for b in blocks
        if b.get("article_candidate") == "yes"
        and b.get("posted_from", "").strip() in UNPOSTED_MARKERS
    ]

    print(f"[article_bridge] drift blocks={len(blocks)}, article_candidate=yes & 未投稿={len(candidates)}")

    if args.dry_run:
        for b in candidates:
            print(f"  - would queue: {b['title'][:60]}")
        return 0

    material_health = check_material_bank_health(VAULT)
    MAKE_ARTICLE_QUEUE.mkdir(parents=True, exist_ok=True)
    written = []
    for b in candidates:
        out = write_queue_item(b, MAKE_ARTICLE_QUEUE, material_warning=material_health["warning"])
        written.append(out.name)
    print(f"[article_bridge] queued {len(written)} item(s) → {MAKE_ARTICLE_QUEUE}")
    for n in written:
        print(f"  - {n}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
