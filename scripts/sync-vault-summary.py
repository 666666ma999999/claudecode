#!/usr/bin/env python3
"""sync-vault-summary.py — vault MOC への atomic append helper

skill (sync-vault-summary) から呼ばれる helper script。
LLM 要約生成は skill 側で行い、本 script は機械的な操作のみ担当:
- edit-history.jsonl から対象ファイル抽出
- repo パス → vault MOC マッピング解決
- MOC への atomic append + frontmatter last_updated 更新

Usage:
    python3 sync-vault-summary.py list <session_id>
        → 同 session の rules/42 要約対象ファイルを行出力 (ts\tfile)

    python3 sync-vault-summary.py resolve <repo_file_path>
        → repo パスから vault MOC 絶対パスを解決 (heuristic + registry)
        未解決なら "UNRESOLVED" を返す

    python3 sync-vault-summary.py append <moc_path> <entry_text>
        → MOC の "## 🔁 最新更新ログ" セクションに entry を prepend
        セクション不在なら frontmatter 直後に新設
        frontmatter `last_updated` を当日へ更新
        同日+同 basename の重複は merge
"""
import argparse
import datetime
import json
import re
import sys
from pathlib import Path

SECTION_TITLE = "## 🔁 最新更新ログ (自動生成・β)"
SECTION_OPEN_ISSUES = "## 📋 Open Issues"
MAX_ENTRIES = 30
ISSUES_LIMIT = 5
VAULT = Path.home() / "Documents" / "Obsidian Vault"

# rules/42 要約対象 PAT (D-1〜D-5 / C-1〜C-5 / H-1〜H-5 / 0-3〜0-5)
TARGET_PAT = re.compile(
    r"/(plan|measures-detail|measure-impact-table|spec|analysis|"
    r"data-sources|data_lineage|schema-|glossary|README|CLAUDE|"
    r"SECURITY|setup-runbook|rationales/).*\.(md|ya?ml)$"
    r"|/tasks/phase-tracker\.md$"
)

# heuristic mapping: repo path prefix → vault MOC relative path
# registry の `**root**:` を補完。registry 改修なしで動かすため
HEURISTIC_MAP = [
    # (path substring, vault MOC relative path)
    ("/prime_suite/prime_ad/", "02_Ai/AI_adscrm/AIads_ope.md"),
    ("/prime_suite/prime_crm/", "02_Ai/AI_adscrm/AIcrm_ope.md"),
    ("/prime_suite/", "02_Ai/AI_adscrm/adscrm_cross.md"),
    ("/biz/make_article/", "02_Ai/make_article/make_article_ope.md"),
]


def cmd_list(session_id: str) -> int:
    log = Path.home() / ".claude" / "state" / "edit-history.jsonl"
    if not log.exists():
        return 0
    seen = {}
    for line in log.read_text().splitlines():
        try:
            d = json.loads(line)
        except Exception:
            continue
        if d.get("session") != session_id:
            continue
        f = d.get("file", "")
        if TARGET_PAT.search(f):
            seen[f] = d.get("ts", "")
    for f, ts in sorted(seen.items(), key=lambda x: x[1]):
        print(f"{ts}\t{f}")
    return 0


def _resolve_moc(repo_file_path: str):
    """repo パスから vault MOC 絶対パスを返す (なければ None)。cmd_resolve / cmd_issues で共用。"""
    for prefix, moc_rel in HEURISTIC_MAP:
        if prefix in repo_file_path:
            moc_abs = VAULT / moc_rel
            if moc_abs.exists():
                return moc_abs
    return None


def cmd_resolve(repo_file_path: str) -> int:
    moc = _resolve_moc(repo_file_path)
    if moc is None:
        print("UNRESOLVED")
        return 1
    print(str(moc))
    return 0


def cmd_issues(repo_path: str) -> int:
    """gh issue list 結果を MOC の ## 📋 Open Issues セクションに反映 (完全置換)。

    認証切れ / git remote 不在 / 該当 MOC 不在は silent fail (rc=0・出力なし)。
    """
    import subprocess

    # directory path 入力時の末尾 / 補正 (HEURISTIC_MAP の prefix は `/` 終端)
    moc = _resolve_moc(repo_path.rstrip("/") + "/")
    if moc is None:
        return 0  # silent fail: project が registry に未登録

    # git remote → owner/repo slug
    try:
        result = subprocess.run(
            ["git", "-C", repo_path, "remote", "get-url", "origin"],
            capture_output=True, text=True, timeout=3,
        )
        if result.returncode != 0:
            return 0
        remote_url = result.stdout.strip()
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return 0
    m = re.search(r"[:/]([^/]+/[^/]+?)(?:\.git)?$", remote_url)
    if not m:
        return 0
    repo_slug = m.group(1)

    # gh issue list
    try:
        result = subprocess.run(
            ["gh", "issue", "list", "-R", repo_slug,
             "--state", "open", "--limit", str(ISSUES_LIMIT),
             "--json", "number,title,labels,updatedAt,url"],
            capture_output=True, text=True, timeout=10,
        )
        if result.returncode != 0:
            return 0  # gh 認証切れ等
        issues = json.loads(result.stdout) if result.stdout.strip() else []
    except (subprocess.TimeoutExpired, json.JSONDecodeError, FileNotFoundError):
        return 0

    # section body 生成
    now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
    if not issues:
        body = f"_No open issues_ (last_synced: {now})\n\n→ 全件: [GitHub Issues](https://github.com/{repo_slug}/issues)\n"
    else:
        rows = []
        for i in issues:
            labels = ",".join(l["name"] for l in i.get("labels") or [])
            updated = (i.get("updatedAt") or "")[:10]
            num = i["number"]
            title = i["title"].replace("|", r"\|")
            url = i.get("url") or f"https://github.com/{repo_slug}/issues/{num}"
            rows.append(f"| [#{num}]({url}) | {title} | {labels} | {updated} |")
        body = (
            f"_last_synced: {now}_\n\n"
            f"| # | Title | Labels | Updated |\n"
            f"|---|---|---|---|\n"
            + "\n".join(rows) + "\n\n"
            f"→ 全件: [GitHub Issues](https://github.com/{repo_slug}/issues)\n"
        )

    text = moc.read_text()
    new_section = f"{SECTION_OPEN_ISSUES}\n\n{body}\n"

    # 既存 ## 📋 Open Issues セクションを次の ## まで完全置換
    pattern = re.compile(
        rf"^{re.escape(SECTION_OPEN_ISSUES)}.*?(?=^## |\Z)",
        re.MULTILINE | re.DOTALL,
    )
    if pattern.search(text):
        text = pattern.sub(new_section, text)
    else:
        # frontmatter 直後に新設
        fm = re.search(r"^---\n.*?\n---\n", text, re.DOTALL)
        if fm:
            insert_at = fm.end()
            text = text[:insert_at] + "\n" + new_section + text[insert_at:]
        else:
            text = new_section + "\n" + text

    # frontmatter last_updated 更新
    if text.startswith("---"):
        text = re.sub(
            r"^last_updated:.*$",
            f"last_updated: {datetime.date.today().isoformat()}",
            text, count=1, flags=re.M,
        )

    # 改行整理
    text = re.sub(r"\n{3,}", "\n\n", text)

    moc.write_text(text)
    print(f"updated {moc} (open issues: {len(issues)} from {repo_slug})")
    return 0


def cmd_append(moc_path: str, entry: str) -> int:
    moc = Path(moc_path)
    if not moc.exists():
        print(f"ERROR: MOC not found: {moc}", file=sys.stderr)
        return 1
    text = moc.read_text()
    today = datetime.date.today().isoformat()

    # frontmatter last_updated 更新 (frontmatter なければスキップ)
    if text.startswith("---"):
        text = re.sub(
            r"^last_updated:.*$",
            f"last_updated: {today}",
            text,
            count=1,
            flags=re.M,
        )

    entry_clean = entry.strip()

    if SECTION_TITLE not in text:
        # frontmatter (---...---) の直後に新設
        m = re.search(r"^---\n.*?\n---\n", text, re.DOTALL)
        if m:
            insert_at = m.end()
            new_section = f"\n{SECTION_TITLE}\n\n{entry_clean}\n\n"
            text = text[:insert_at] + new_section + text[insert_at:]
        else:
            text = f"{SECTION_TITLE}\n\n{entry_clean}\n\n" + text
    else:
        # 同日 + basename の重複 merge (時刻や行番号の違いに耐性あり)
        # entry 例: "- 2026-05-25 13:30 [plan.md L196] ..."
        m = re.match(r"^-?\s*(\d{4}-\d{2}-\d{2})[^\n]*?\[([^\] ]+\.\w+)", entry_clean)
        if m:
            date_str = m.group(1)
            basename = m.group(2)
            # 既存の同日+同 basename entry を 1 行ごと削除 (次行までを 1 entry とみなす簡易版)
            pattern = rf"(?m)^-\s*{re.escape(date_str)}[^\n]*?\[{re.escape(basename)}[^\n]*\n?"
            text = re.sub(pattern, "", text)
            # 空行整理
            text = re.sub(r"\n{3,}", "\n\n", text)

        # セクション直下に prepend
        idx = text.index(SECTION_TITLE) + len(SECTION_TITLE)
        text = text[:idx] + f"\n\n{entry_clean}" + text[idx:]
        # 余分な改行整理
        text = re.sub(r"\n{3,}", "\n\n", text)

    moc.write_text(text)
    print(f"appended to {moc} (last_updated={today})")
    return 0


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    sub = p.add_subparsers(dest="cmd", required=True)

    pl = sub.add_parser("list")
    pl.add_argument("session_id")

    pr = sub.add_parser("resolve")
    pr.add_argument("repo_file_path")

    pa = sub.add_parser("append")
    pa.add_argument("moc_path")
    pa.add_argument("entry")

    pi = sub.add_parser("issues")
    pi.add_argument("repo_path", help="repo root or any path inside repo (cwd でも可)")

    args = p.parse_args()

    if args.cmd == "list":
        return cmd_list(args.session_id)
    if args.cmd == "resolve":
        return cmd_resolve(args.repo_file_path)
    if args.cmd == "append":
        return cmd_append(args.moc_path, args.entry)
    if args.cmd == "issues":
        return cmd_issues(args.repo_path)
    return 1


if __name__ == "__main__":
    sys.exit(main())
