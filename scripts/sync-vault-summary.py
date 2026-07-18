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
from __future__ import annotations

import argparse
import datetime
import json
import re
import sys
from pathlib import Path

SECTION_TITLE = "## 🔁 最新更新ログ (自動生成・β)"
SECTION_OPEN_ISSUES = "## 📋 Open Issues"
SECTION_LIFECYCLE = "## 施策サマリ一覧 (自動生成・β)"
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
    ("/prime_suite/prime_ad/", "02_Ai/AI_adscrm/AIads/AIads_ope.md"),
    ("/prime_suite/prime_crm/", "02_Ai/AI_adscrm/AIcrm/AIcrm_ope.md"),
    ("/prime_suite/", "02_Ai/AI_adscrm/adscrm_cross.md"),
    ("/biz/make_article/", "02_Ai/x-buzz/make_article/make_article_ope.md"),
    ("/biz/autopost/", "02_Ai/x-buzz/autopost/autopost_ope.md"),
    ("/biz/influx/", "02_Ai/influx/influx_ope.md"),
    ("/biz/pokeca-invest/", "02_Ai/pokeca-invest/pokeca-invest_ope.md"),
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

    # 自動フィードは MOC 最下段の「自動生成ゾーン」へ (rules/41 §④・2026-06-14)。
    # 人間向け司令塔セクションより上に出さない。既存セクションを除去してから末尾へ。
    pattern = re.compile(
        rf"^{re.escape(SECTION_OPEN_ISSUES)}.*?(?=^## |\Z)",
        re.MULTILINE | re.DOTALL,
    )
    text = pattern.sub("", text)
    text = text.rstrip() + "\n\n" + new_section

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
    # RETIRED 2026-06-14: 「🔁 最新更新ログ」MOC 追記は廃止 (ユーザー裁定・rules/41 §④)。
    # 理由: 人間は読み返さず、AI 判断用データとしても decisions.md(毎プロンプト注入)
    #       + git log + claude-mem の劣化コピー (git log と 1:1・rules/20 Dual-Path/SSoT 違反)。
    # MOC には書かず no-op で返す。AI の「最近の活動」把握は本物の SSoT を参照すること。
    print(
        "RETIRED: 最新更新ログ への append は廃止されました "
        "(rules/41 §④ / AI は decisions.md + git log + claude-mem を参照)",
        file=sys.stderr,
    )
    return 0


def cmd_lifecycle_view(moc_path: str, results_jsonl: str | None = None) -> int:
    """results.jsonl から派生 view を生成し MOC の SECTION_LIFECYCLE を完全上書き。

    各 art_id について draft_created → review_passed → posted → metrics_snapshot の
    最終状態を集計し、表形式で MOC に書き出す。

    状態判定:
      - 成功: posted + metrics_snapshot(28d) で impressions >= 10000
      - 失敗: posted + metrics_snapshot(28d) で impressions < 1000 or failed event
      - 公開済: posted のみ
      - レビュー完了: review_passed のみ
      - 書きかけ: draft_created のみ
      - archived: archived event あり
    """
    from collections import defaultdict

    moc = Path(moc_path)
    if not moc.exists():
        print(f"ERROR: MOC not found: {moc}", file=sys.stderr)
        return 1

    jsonl_path = Path(results_jsonl) if results_jsonl else (
        Path.home() / "Desktop" / "biz" / "make_article" / "output" / "published" / "results.jsonl"
    )
    if not jsonl_path.exists():
        print(f"ERROR: results.jsonl not found: {jsonl_path}", file=sys.stderr)
        return 1

    events_by_art: dict[str, list[dict]] = defaultdict(list)
    for line in jsonl_path.read_text().splitlines():
        if not line.strip():
            continue
        try:
            d = json.loads(line)
        except json.JSONDecodeError:
            continue
        art_id = d.get("art_id")
        if art_id:
            events_by_art[art_id].append(d)

    def _classify(events: list[dict]) -> tuple[str, str]:
        types = {e["event"] for e in events}
        if "archived" in types and "posted" not in types:
            return ("📦", "archived")
        if "failed" in types:
            return ("🔴", "failed")
        if "posted" in types:
            ms = [e for e in events if e.get("event") == "metrics_snapshot" and e.get("snapshot_at") == "28d"]
            if ms:
                latest = max(ms, key=lambda e: e.get("ts", ""))
                imp = int(latest.get("impressions", 0))
                if imp >= 10000:
                    return ("🏆", f"success ({imp:,} imp)")
                if imp < 1000:
                    return ("📉", f"low ({imp} imp)")
                return ("📊", f"posted ({imp:,} imp)")
            return ("📤", "posted")
        if "review_passed" in types:
            return ("✅", "review_passed")
        if "draft_created" in types:
            return ("✏️", "drafting")
        return ("❓", "unknown")

    def _title(events: list[dict]) -> str:
        for ev_type in ("draft_created", "posted", "review_passed"):
            for e in events:
                if e.get("event") == ev_type and e.get("title"):
                    return str(e["title"])
        return ""

    def _category(events: list[dict]) -> str:
        for e in events:
            if e.get("category"):
                return str(e["category"])
        return ""

    rows: list[tuple[str, str, str, str, str]] = []
    for art_id, events in sorted(events_by_art.items()):
        icon, state = _classify(events)
        rows.append((icon, art_id, state, _category(events), _title(events)))

    today = datetime.date.today().isoformat()
    body_lines = [
        SECTION_LIFECYCLE,
        "",
        f"_results.jsonl から自動生成 (last_synced: {today})・sync-vault-summary skill `lifecycle-view` cmd で更新_",
        "",
        f"**集計**: {len(rows)} article (state=書きかけ/レビュー完了/公開済/成功/失敗/archived の filter で表現)",
        "",
        "| 状態 | ID | 詳細 | カテゴリ | タイトル |",
        "|:-:|---|---|---|---|",
    ]
    for icon, art_id, state, cat, title in rows:
        title_short = title[:50] + ("…" if len(title) > 50 else "")
        body_lines.append(f"| {icon} | `{art_id}` | {state} | {cat} | {title_short} |")
    body_lines.append("")

    new_section = "\n".join(body_lines)

    text = moc.read_text()
    pattern = re.compile(
        rf"^{re.escape(SECTION_LIFECYCLE)}.*?(?=^## |\Z)",
        re.MULTILINE | re.DOTALL,
    )
    if pattern.search(text):
        text = pattern.sub(new_section, text)
    else:
        # frontmatter 直後 + SECTION_TITLE (最新更新ログ) の後に挿入
        fm_end = re.search(r"^---\n.*?\n---\n", text, re.DOTALL)
        if fm_end:
            insert_at = fm_end.end()
            text = text[:insert_at] + "\n" + new_section + "\n" + text[insert_at:]
        else:
            text = new_section + "\n" + text

    if text.startswith("---"):
        text = re.sub(
            r"^last_updated:.*$",
            f"last_updated: {today}",
            text, count=1, flags=re.M,
        )

    text = re.sub(r"\n{3,}", "\n\n", text)
    moc.write_text(text)
    print(f"updated {moc} (lifecycle view: {len(rows)} articles)")
    return 0


def cmd_kanban_view(board_path: str, results_jsonl: str | None = None) -> int:
    """results.jsonl から obsidian-kanban plugin 互換 Kanban board を完全上書き生成。

    plugin 仕様: `kanban-plugin: basic` frontmatter + `## カラム名` + `- [ ] カード`
    plugin 未インストールでも普通の Markdown チェックリストとして閲覧可。
    """
    from collections import defaultdict

    board = Path(board_path)
    jsonl_path = Path(results_jsonl) if results_jsonl else (
        Path.home() / "Desktop" / "biz" / "make_article" / "output" / "published" / "results.jsonl"
    )
    if not jsonl_path.exists():
        print(f"ERROR: results.jsonl not found: {jsonl_path}", file=sys.stderr)
        return 1

    events_by_art: dict[str, list[dict]] = defaultdict(list)
    for line in jsonl_path.read_text().splitlines():
        if not line.strip():
            continue
        try:
            d = json.loads(line)
        except json.JSONDecodeError:
            continue
        if art_id := d.get("art_id"):
            events_by_art[art_id].append(d)

    columns: dict[str, list[str]] = {
        "✏️ 書きかけ (drafting)": [],
        "✅ レビュー完了 (review_passed)": [],
        "📤 公開済 (posted)": [],
        "🏆 成功 (success・imp ≥ 10k)": [],
        "🔴 失敗 (failed / imp < 1k)": [],
        "📦 archived": [],
    }

    repo_root = Path.home() / "Desktop" / "biz" / "make_article"
    drafts_dir = repo_root / "output" / "drafts"

    for art_id, events in sorted(events_by_art.items()):
        types = {e["event"] for e in events}
        title = ""
        for e in events:
            if e.get("title"):
                title = str(e["title"])
                break
        title_short = title[:60] + ("…" if len(title) > 60 else "")

        # repo file 解決 (art_NNN_*.md or full name)
        candidates = list(drafts_dir.glob(f"{art_id}_*.md")) if art_id.startswith("art_") else \
                     list(drafts_dir.glob(f"{art_id}*.md"))
        link = ""
        if candidates:
            link = f" [→ open](file://{candidates[0]})"

        card = f"- [ ] **{art_id}**: {title_short}{link}"

        if "archived" in types and "posted" not in types:
            columns["📦 archived"].append(card)
        elif "failed" in types and "posted" in types:
            columns["🔴 失敗 (failed / imp < 1k)"].append(card)
        elif "failed" in types:
            columns["🔴 失敗 (failed / imp < 1k)"].append(card)
        elif "posted" in types:
            ms = [e for e in events if e.get("event") == "metrics_snapshot" and e.get("snapshot_at") == "28d"]
            if ms:
                latest = max(ms, key=lambda e: e.get("ts", ""))
                imp = int(latest.get("impressions", 0))
                if imp >= 10000:
                    columns["🏆 成功 (success・imp ≥ 10k)"].append(card)
                elif imp < 1000:
                    columns["🔴 失敗 (failed / imp < 1k)"].append(card)
                else:
                    columns["📤 公開済 (posted)"].append(card)
            else:
                columns["📤 公開済 (posted)"].append(card)
        elif "review_passed" in types:
            columns["✅ レビュー完了 (review_passed)"].append(card)
        elif "draft_created" in types:
            columns["✏️ 書きかけ (drafting)"].append(card)

    today = datetime.date.today().isoformat()
    lines = [
        "---",
        "kanban-plugin: basic",
        f"last_updated: {today}",
        "tags: [project/make_article, type/kanban, source/results.jsonl]",
        "ssot: file:///Users/masaaki_nagasawa/Desktop/biz/make_article/output/published/results.jsonl",
        "---",
        "",
        "# 記事ライフサイクル Kanban (自動生成・β)",
        "",
        f"_results.jsonl から自動生成 (last_synced: {today})。sync-vault-summary skill `kanban-view` cmd で更新。obsidian-kanban plugin 必須 (未インストール時はチェックリスト表示)。_",
        "",
        f"**合計 {sum(len(v) for v in columns.values())} 件 / 出典: [[make_article_ope]] / 状態 SSoT: results.jsonl (event log)**",
        "",
    ]
    for col_name, cards in columns.items():
        lines.append(f"## {col_name}")
        lines.append("")
        if not cards:
            lines.append("- [ ] (該当なし)")
        else:
            lines.extend(cards)
        lines.append("")

    lines.append("%% kanban:settings")
    lines.append('```')
    lines.append('{"kanban-plugin":"basic","new-note-folder":"02_Ai/x-buzz/make_article"}')
    lines.append('```')
    lines.append("%%")

    board.parent.mkdir(parents=True, exist_ok=True)
    board.write_text("\n".join(lines) + "\n")
    print(f"updated {board} (kanban view: {sum(len(v) for v in columns.values())} cards)")
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

    plv = sub.add_parser("lifecycle-view")
    plv.add_argument("moc_path")
    plv.add_argument("--source", default=None, help="results.jsonl path (default: make_article)")

    pkv = sub.add_parser("kanban-view")
    pkv.add_argument("board_path", help="出力先 vault Kanban MD path")
    pkv.add_argument("--source", default=None, help="results.jsonl path (default: make_article)")

    args = p.parse_args()

    if args.cmd == "list":
        return cmd_list(args.session_id)
    if args.cmd == "resolve":
        return cmd_resolve(args.repo_file_path)
    if args.cmd == "append":
        return cmd_append(args.moc_path, args.entry)
    if args.cmd == "issues":
        return cmd_issues(args.repo_path)
    if args.cmd == "lifecycle-view":
        return cmd_lifecycle_view(args.moc_path, args.source)
    if args.cmd == "kanban-view":
        return cmd_kanban_view(args.board_path, args.source)
    return 1


if __name__ == "__main__":
    sys.exit(main())
