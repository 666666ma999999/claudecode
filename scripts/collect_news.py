#!/usr/bin/env python3
"""
Daily news collector for ~/.claude global env.

- Reads sources from ~/.claude/data/news_sources.yaml (subset YAML, no external dep)
- Fetches RSS / GitHub releases / GitHub commits
- Dedupes via sqlite (~/.claude/state/news_seen.sqlite)
- Appends new items to ~/Documents/Obsidian Vault/.raw/news/YYYY-MM-DD.jsonl
- Stdlib-only (urllib, xml.etree, sqlite3, json, hashlib)

Triggered by launchd: ~/Library/LaunchAgents/com.masa.claude-news-collect.plist
"""

import argparse
import datetime as dt
import hashlib
import json
import re
import sqlite3
import sys
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path

UA = "claude-news-collect/1.0 (+~/.claude/scripts/collect_news.py)"
TIMEOUT = 15


def load_sources(yaml_path: Path) -> list[dict]:
    """Minimal YAML subset parser for news_sources.yaml structure."""
    sources, cur = [], None
    for raw in yaml_path.read_text(encoding="utf-8").splitlines():
        line = raw.rstrip()
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        if line.startswith("sources:"):
            continue
        m = re.match(r"^\s*-\s+name:\s*(.+)$", line)
        if m:
            if cur:
                sources.append(cur)
            cur = {"name": m.group(1).strip()}
            continue
        m = re.match(r"^\s+(\w+):\s*(.+)$", line)
        if m and cur is not None:
            key, val = m.group(1), m.group(2).strip()
            if val.startswith("[") and val.endswith("]"):
                val = [v.strip() for v in val[1:-1].split(",") if v.strip()]
            cur[key] = val
    if cur:
        sources.append(cur)
    return sources


def canon_url(url: str) -> str:
    p = urllib.parse.urlsplit(url)
    q = [(k, v) for k, v in urllib.parse.parse_qsl(p.query) if not k.startswith("utm_")]
    return urllib.parse.urlunsplit(
        (p.scheme, p.netloc.lower(), p.path.rstrip("/"), urllib.parse.urlencode(q), "")
    )


def url_hash(url: str) -> str:
    return hashlib.sha256(canon_url(url).encode()).hexdigest()


def http_get(url: str, accept: str = "application/xml,application/json,text/html") -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": accept})
    with urllib.request.urlopen(req, timeout=TIMEOUT) as r:
        return r.read()


def parse_rss(xml_bytes: bytes) -> list[dict]:
    """Parse RSS 2.0 or Atom 1.0."""
    items = []
    try:
        root = ET.fromstring(xml_bytes)
    except ET.ParseError:
        return items
    # RSS 2.0
    for it in root.iter("item"):
        title = (it.findtext("title") or "").strip()
        link = (it.findtext("link") or "").strip()
        pub = (it.findtext("pubDate") or "").strip()
        desc = (it.findtext("description") or "").strip()
        if link:
            items.append({"title": title, "url": link, "published_at": pub, "summary": desc[:500]})
    # Atom
    ns = "{http://www.w3.org/2005/Atom}"
    for it in root.iter(f"{ns}entry"):
        title = (it.findtext(f"{ns}title") or "").strip()
        link_el = it.find(f"{ns}link")
        link = link_el.get("href") if link_el is not None else ""
        pub = (it.findtext(f"{ns}updated") or it.findtext(f"{ns}published") or "").strip()
        summary = (it.findtext(f"{ns}summary") or it.findtext(f"{ns}content") or "").strip()
        if link:
            items.append({"title": title, "url": link, "published_at": pub, "summary": summary[:500]})
    return items


def fetch_github_releases(repo: str) -> list[dict]:
    api = f"https://api.github.com/repos/{repo}/releases?per_page=10"
    try:
        data = json.loads(http_get(api, "application/json"))
    except Exception:
        return []
    out = []
    for r in data:
        out.append({
            "title": f"[{repo}] {r.get('name') or r.get('tag_name')}",
            "url": r.get("html_url", ""),
            "published_at": r.get("published_at", ""),
            "summary": (r.get("body") or "")[:500],
        })
    return [x for x in out if x["url"]]


def fetch_github_commits(repo: str) -> list[dict]:
    api = f"https://api.github.com/repos/{repo}/commits?per_page=15"
    try:
        data = json.loads(http_get(api, "application/json"))
    except Exception:
        return []
    out = []
    for c in data:
        msg = (c.get("commit", {}).get("message") or "").splitlines()[0]
        out.append({
            "title": f"[{repo}] {msg}",
            "url": c.get("html_url", ""),
            "published_at": c.get("commit", {}).get("author", {}).get("date", ""),
            "summary": msg[:500],
        })
    return [x for x in out if x["url"]]


HTML_SCRAPE_STATE = Path.home() / ".claude/state/html_scrape_state.json"
HTML_DIFF_MIN_BYTES = 200


def _load_html_state() -> dict:
    if not HTML_SCRAPE_STATE.exists():
        return {}
    try:
        return json.loads(HTML_SCRAPE_STATE.read_text())
    except Exception:
        return {}


def _save_html_state(state: dict) -> None:
    HTML_SCRAPE_STATE.parent.mkdir(parents=True, exist_ok=True)
    HTML_SCRAPE_STATE.write_text(json.dumps(state, indent=2, ensure_ascii=False))


def _extract_title(html_bytes: bytes) -> str:
    try:
        text = html_bytes.decode("utf-8", errors="replace")
    except Exception:
        return ""
    m = re.search(r"<title[^>]*>(.*?)</title>", text, re.IGNORECASE | re.DOTALL)
    if m:
        return re.sub(r"\s+", " ", m.group(1)).strip()[:200]
    return ""


def fetch_html_scrape(source: dict) -> list[dict]:
    """Phase 0 html_scrape: content_hash 差分検知のみ。本文抽出はしない (Plan §3 Non-Goal)。

    動作:
      1. GET でページ取得
      2. content_hash (sha256) を ~/.claude/state/html_scrape_state.json と比較
      3. 差分あり + サイズ変動 ≥ HTML_DIFF_MIN_BYTES → 1 件返す
      4. 差分なし or サイズ変動小 → 空配列 (ノイズ抑制)

    返す item:
      - title: <title> タグから抽出 (デコード失敗時は url)
      - url: source の url そのまま (毎回同じ URL)
      - published_at: 検知時刻 (ISO 8601)
      - summary: "Content changed: <prev_len> → <new_len> bytes"

    重複排除との関係:
      - 既存 url_hash 重複排除は url ベース → html_scrape は同じ url が複数回出るので衝突する
      - 対策: html_scrape は item url に `#diff-<timestamp>` を付与し canon_url 後も unique 化
    """
    url = source["url"]
    try:
        body = http_get(url, accept="text/html,application/xhtml+xml")
    except Exception as e:
        print(f"[warn] html_scrape {source['name']}: {e}", file=sys.stderr)
        return []

    new_hash = hashlib.sha256(body).hexdigest()
    new_len = len(body)
    state = _load_html_state()
    prev = state.get(source["name"], {})
    prev_hash = prev.get("hash")
    prev_len = prev.get("len", 0)

    state[source["name"]] = {
        "hash": new_hash,
        "len": new_len,
        "checked_at": dt.datetime.now().isoformat(timespec="seconds"),
    }
    _save_html_state(state)

    if prev_hash is None:
        return [{
            "title": _extract_title(body) or f"[html_scrape baseline] {source['name']}",
            "url": f"{url}#baseline-{dt.date.today().isoformat()}",
            "published_at": dt.datetime.now().isoformat(timespec="seconds"),
            "summary": f"Initial baseline captured ({new_len} bytes). Future diffs will be reported.",
        }]

    if new_hash == prev_hash:
        return []

    if abs(new_len - prev_len) < HTML_DIFF_MIN_BYTES:
        return []

    return [{
        "title": _extract_title(body) or f"[html_scrape diff] {source['name']}",
        "url": f"{url}#diff-{dt.datetime.now().strftime('%Y%m%dT%H%M%S')}",
        "published_at": dt.datetime.now().isoformat(timespec="seconds"),
        "summary": f"Content changed: {prev_len} → {new_len} bytes (Δ={new_len - prev_len:+d}). Open URL to inspect.",
    }]


def fetch(source: dict) -> list[dict]:
    t = source.get("type")
    try:
        if t == "rss":
            return parse_rss(http_get(source["url"]))
        if t == "atom":
            return parse_rss(http_get(source["url"]))
        if t == "github_releases":
            return fetch_github_releases(source["repo"])
        if t == "github_commits":
            return fetch_github_commits(source["repo"])
        if t == "html_scrape":
            return fetch_html_scrape(source)
    except Exception as e:
        print(f"[warn] {source['name']}: {e}", file=sys.stderr)
    return []


P0_KEYWORDS = ("breaking", "deprecat", "remove", "security", "vulnerab", "incident", "outage", "critical")
P1_KEYWORDS = ("release", "new feature", "add", "introduc", "support", "launch", "v2.", "v3.")


def assign_priority(item: dict, tags: list[str]) -> str:
    text = (item.get("title", "") + " " + item.get("summary", "")).lower()
    if any(k in text for k in P0_KEYWORDS):
        return "P0"
    if "official" in tags and any(k in text for k in P1_KEYWORDS):
        return "P1"
    if "official" in tags:
        return "P1"
    return "P2"


def update_health(health_path: Path, source_name: str, n_items: int, source_type: str = "") -> None:
    """Track last_success_at per source. 72h+ silence will be flagged.

    html_scrape は「差分なし=0 件返却」が正常状態なので、success 扱いにする
    (例外時は fetch_html_scrape 内で stderr 出力 + 空配列を返す。例外と差分なしの区別はつかないため
     html_scrape は常に success 扱い。真の失敗検知が必要なら別途 stderr ログ監視で対応)。
    """
    now = dt.datetime.now().isoformat(timespec="seconds")
    try:
        data = json.loads(health_path.read_text()) if health_path.exists() else {}
    except Exception:
        data = {}
    entry = data.get(source_name, {"consecutive_failures": 0})
    if n_items > 0 or source_type == "html_scrape":
        entry["last_success_at"] = now
        entry["consecutive_failures"] = 0
    else:
        entry["consecutive_failures"] = entry.get("consecutive_failures", 0) + 1
    entry["last_run_at"] = now
    data[source_name] = entry
    health_path.parent.mkdir(parents=True, exist_ok=True)
    health_path.write_text(json.dumps(data, indent=2, ensure_ascii=False))


def init_db(conn: sqlite3.Connection) -> None:
    conn.execute(
        "CREATE TABLE IF NOT EXISTS seen "
        "(h TEXT PRIMARY KEY, source TEXT, url TEXT, first_seen TEXT)"
    )


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out-dir", required=True)
    ap.add_argument("--state-db", required=True)
    ap.add_argument("--sources", required=True)
    ap.add_argument("--health", default=str(Path.home() / ".claude/state/news_health.json"))
    args = ap.parse_args()

    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    today = dt.date.today().isoformat()
    jsonl_path = out_dir / f"{today}.jsonl"

    conn = sqlite3.connect(args.state_db)
    init_db(conn)

    sources = load_sources(Path(args.sources))
    health_path = Path(args.health)
    new_count, total_count = 0, 0
    with jsonl_path.open("a", encoding="utf-8") as fp:
        for s in sources:
            items = fetch(s)
            total_count += len(items)
            new_for_source = 0
            tags = s.get("tags", [])
            for item in items:
                if not item.get("url"):
                    continue
                h = url_hash(item["url"])
                if conn.execute("SELECT 1 FROM seen WHERE h=?", (h,)).fetchone():
                    continue
                row = {
                    "source": s["name"],
                    "tags": tags,
                    "priority": assign_priority(item, tags),
                    "url_hash": h,
                    "fetched_at": dt.datetime.now().isoformat(timespec="seconds"),
                    **item,
                }
                fp.write(json.dumps(row, ensure_ascii=False) + "\n")
                conn.execute(
                    "INSERT INTO seen VALUES (?,?,?,?)",
                    (h, s["name"], item["url"], today),
                )
                new_count += 1
                new_for_source += 1
            update_health(health_path, s["name"], len(items), s.get("type", ""))
    conn.commit()
    conn.close()
    print(f"[collect_news] {today}: {new_count} new / {total_count} fetched → {jsonl_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
