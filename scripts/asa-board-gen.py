#!/usr/bin/env python3
"""asa-board-gen.py — 朝ボード自動生成

vault の 03_ClaudeEnv/asa-board.md を「状態を持たない再生成ビュー」として
丸ごと作り直す。正本台帳は 03_ClaudeEnv/asa-items.md（手書き）。

入力:
  (a) asa-items.md の 🔴/🟡/🟢 セクション表（未裁定行の抽出）
  (b) 各プロジェクト INBOX（02_Ai/*/prompts/*_INBOX.md, 03_ClaudeEnv/prompts/ClaudeEnv_INBOX.md）の 🔵 行数
  (c) vault 全体の "✅待ち" マーカー出現ファイル
  (d) wiki 取り込みキューの未処理行
  (e) collector-health.md の「定期ジョブ健全性」🔴（sessionstart-env-recall.sh と同じ判定ロジックを流用）

出力: 03_ClaudeEnv/asa-board.md（atomic write）。
fail-loud: 台帳 (a) が読めない場合は更新せず stderr にエラーを出して exit 1。
(b)〜(e) の個別失敗は続行し「🩺 スキャン健全性」節に計上する。

2026-07-13 新設。
"""
import os
import re
import sys
from datetime import datetime, timedelta
from pathlib import Path

VAULT = Path(os.environ.get("OBSIDIAN_VAULT", "/Users/masaaki/Documents/Obsidian Vault"))
LEDGER = VAULT / "03_ClaudeEnv" / "asa-items.md"
BOARD = VAULT / "03_ClaudeEnv" / "asa-board.md"
COLLECTOR_HEALTH = VAULT / "03_ClaudeEnv" / "collector-health.md"

EXCLUDE_DIR_NAMES = {"templates", "_archive", "archives", ".obsidian"}

read_failures = []  # list[str] (relパス)
parse_warnings = 0
scanned_file_count = 0


def rel(p: Path) -> str:
    try:
        return str(p.relative_to(VAULT))
    except ValueError:
        return str(p)


def read_text_safe(path: Path):
    """(text, error_or_None) を返す。読めなければ read_failures に積む。"""
    global read_failures
    try:
        return path.read_text(encoding="utf-8"), None
    except Exception as e:
        read_failures.append(f"{rel(path)} ({e.__class__.__name__})")
        return None, e


# ---------------------------------------------------------------------------
# Markdown table parsing (asa-items.md 用の最小パーサ)
# ---------------------------------------------------------------------------

def split_row(line: str):
    line = line.strip()
    if line.startswith("|"):
        line = line[1:]
    if line.endswith("|"):
        line = line[:-1]
    return [c.strip() for c in line.split("|")]


def section_lines(full_text: str, marker: str):
    """`## ` 見出し行に marker (絵文字) を含むセクションの本文行を返す。次の `## ` まで。"""
    out = []
    capture = False
    for line in full_text.splitlines():
        if line.startswith("## "):
            if marker in line:
                capture = True
                continue
            if capture:
                break
            capture = False
            continue
        if capture:
            out.append(line)
    return out


def parse_table(lines):
    """先頭の Markdown 表 (header / 区切り / データ行) をパースする。
    戻り値: (header_cells, data_rows) 。列数不一致行はスキップし parse_warnings をインクリメント。
    """
    global parse_warnings
    table_lines = [l for l in lines if l.strip().startswith("|")]
    if len(table_lines) < 2:
        return [], []
    header = split_row(table_lines[0])
    data_lines = table_lines[2:]  # [0]=header [1]=separator
    rows = []
    for dl in data_lines:
        cells = split_row(dl)
        if len(cells) != len(header):
            parse_warnings += 1
            continue
        rows.append(cells)
    return header, rows


def col_index(header, name):
    try:
        return header.index(name)
    except ValueError:
        return -1


# ---------------------------------------------------------------------------
# (a) 台帳 asa-items.md
# ---------------------------------------------------------------------------

def load_ledger():
    """台帳を読み 🔴/🟡/🟢 の未裁定行を抽出する。読めなければ None を返す (呼び出し側で fail-loud)。"""
    text, err = read_text_safe(LEDGER)
    if text is None:
        return None

    global scanned_file_count
    scanned_file_count += 1

    red_header, red_rows_all = parse_table(section_lines(text, "🔴"))
    yellow_header, yellow_rows_all = parse_table(section_lines(text, "🟡"))
    green_header, green_rows_all = parse_table(section_lines(text, "🟢"))

    # 🔴: 「裁定」列が空の行のみ
    red_pending = []
    idx = col_index(red_header, "裁定")
    if idx >= 0:
        for row in red_rows_all:
            if idx < len(row) and row[idx].strip() == "":
                red_pending.append(row)
    else:
        red_pending = list(red_rows_all)

    # 🟡: 「❌」列が空の行のみ
    yellow_pending = []
    idx = col_index(yellow_header, "❌")
    if idx >= 0:
        for row in yellow_rows_all:
            if idx < len(row) and row[idx].strip() == "":
                yellow_pending.append(row)
    else:
        yellow_pending = list(yellow_rows_all)

    # 🟢: 直近 14 日
    green_recent = []
    idx = col_index(green_header, "日付")
    today = datetime.now().date()
    cutoff = today - timedelta(days=13)  # today 含め 14 日窓
    for row in green_rows_all:
        if idx < 0 or idx >= len(row):
            continue
        d = row[idx].strip()
        m = re.match(r"^(\d{4}-\d{2}-\d{2})", d)
        if not m:
            continue
        try:
            row_date = datetime.strptime(m.group(1), "%Y-%m-%d").date()
        except ValueError:
            continue
        if row_date >= cutoff:
            green_recent.append(row)

    return {
        "red_header": red_header, "red_pending": red_pending,
        "yellow_header": yellow_header, "yellow_pending": yellow_pending,
        "green_header": green_header, "green_recent": green_recent,
    }


# ---------------------------------------------------------------------------
# fenced code block / quote 行を除いてスキャンする共通ヘルパ
# ---------------------------------------------------------------------------

def iter_content_lines(text: str):
    """fenced code block（``` 内）と引用行（> 開始）を除いた行を yield する。"""
    in_fence = False
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith("```"):
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        if stripped.startswith(">"):
            continue
        yield line


# ---------------------------------------------------------------------------
# (b) プロジェクト INBOX の 🔵 行
# ---------------------------------------------------------------------------

def scan_inboxes():
    global scanned_file_count
    files = sorted(VAULT.glob("02_Ai/*/prompts/*_INBOX.md"))
    claude_env_inbox = VAULT / "03_ClaudeEnv" / "prompts" / "ClaudeEnv_INBOX.md"
    if claude_env_inbox.exists() and claude_env_inbox not in files:
        files.append(claude_env_inbox)

    results = []
    for f in files:
        text, err = read_text_safe(f)
        scanned_file_count += 1
        if text is None:
            continue
        # 実案件のみ数える: 全 INBOX 共通のテンプレ行（セクション見出し・使い方説明）は除外。
        # 「🔵 セクション内の行」に限定し、さらに定型文パターンを弾く（2026-07-13 偽陽性修正:
        # 旧実装は見出し+説明文で 28 件と過大計上。実案件は数件だった）。
        TEMPLATE_PATTERNS = ("投函🔵 → 記録📒", "INBOX見て", "やってほしいことを 🔵 に貼り")
        # HTML コメント（<!-- 例: ... --> の投函例示）は案件ではないので丸ごと除去
        import re as _re
        text = _re.sub(r"<!--.*?-->", "", text, flags=_re.S)
        matched = []
        in_blue_section = False
        for l in iter_content_lines(text):
            s = l.strip()
            if s.startswith("#"):
                in_blue_section = "🔵" in s
                continue
            if not in_blue_section or not s:
                continue
            if s.startswith(">") or s in ("---", "***"):
                continue
            if any(pat in s for pat in TEMPLATE_PATTERNS):
                continue
            matched.append(s[:60])
        if matched:
            results.append({"file": f, "count": len(matched), "lines": matched})
    return results


# ---------------------------------------------------------------------------
# (c) vault 全体の "✅待ち" マーカー
# ---------------------------------------------------------------------------

def scan_check_wait():
    global scanned_file_count
    results = []
    for f in VAULT.rglob("*.md"):
        if f == BOARD or f == LEDGER:
            continue
        parts = set(f.relative_to(VAULT).parts)
        if parts & EXCLUDE_DIR_NAMES:
            continue
        text, err = read_text_safe(f)
        scanned_file_count += 1
        if text is None:
            continue
        matched = [l.strip()[:60] for l in iter_content_lines(text) if "✅待ち" in l]
        if matched:
            results.append({"file": f, "count": len(matched), "lines": matched})
    return results


# ---------------------------------------------------------------------------
# (d) wiki 取り込みキュー
# ---------------------------------------------------------------------------

def scan_wiki_queue():
    global scanned_file_count
    candidate = VAULT / "wiki" / "wiki-ingest-queue.md"
    if not candidate.exists():
        found = sorted(VAULT.glob("**/wiki-ingest-queue.md"))
        candidate = found[0] if found else None
    if candidate is None:
        return None  # 見つからない = 個別失敗として健全性に計上
    text, err = read_text_safe(candidate)
    scanned_file_count += 1
    if text is None:
        return None
    matched = [l.strip()[:60] for l in text.splitlines() if "- [ ]" in l or "⬜" in l]
    return {"file": candidate, "count": len(matched), "lines": matched}


# ---------------------------------------------------------------------------
# (e) 異常: collector-health.md の「定期ジョブ健全性」🔴
#     sessionstart-env-recall.sh の判定ロジック（見張り自身の死活 → 🔴行カウント）を流用
# ---------------------------------------------------------------------------

def scan_anomalies():
    global scanned_file_count
    if not COLLECTOR_HEALTH.exists():
        return {"mode": "unavailable", "items": []}

    mtime = datetime.fromtimestamp(COLLECTOR_HEALTH.stat().st_mtime)
    scanned_file_count += 1
    if datetime.now() - mtime > timedelta(hours=48):
        return {
            "mode": "watchdog_stale",
            "items": ["🚨 見張り役(collector-health)自身が2日以上未更新 — daily 8:00 ジョブ停止の疑い（launchctl list | grep masa で確認）"],
        }

    text, err = read_text_safe(COLLECTOR_HEALTH)
    if text is None:
        return {"mode": "unavailable", "items": []}

    section = []
    capture = False
    subsection = ""
    for line in text.splitlines():
        if line.startswith("## "):
            if "定期ジョブ健全性" in line:
                capture = True
                continue
            if capture:
                break
            capture = False
            continue
        if capture:
            if line.startswith("### "):
                subsection = line.lstrip("# ").strip()
            section.append((subsection, line))

    items = []
    for subsection, line in section:
        if line.strip().startswith("| 🔴"):
            cells = split_row(line)
            job = cells[1] if len(cells) > 1 else "?"
            detail = cells[2] if len(cells) > 2 else ""
            items.append(f"🔴 {subsection}: `{job}`" + (f"（{detail}）" if detail else ""))

    return {"mode": "ok", "items": items}


# ---------------------------------------------------------------------------
# 出力生成
# ---------------------------------------------------------------------------

def render_row(header, row):
    return "| " + " | ".join(row) + " |"


def render_table(header, rows):
    if not rows:
        return "（該当なし）\n"
    out = ["| " + " | ".join(header) + " |", "|" + "|".join(["---"] * len(header)) + "|"]
    for row in rows:
        out.append(render_row(header, row))
    return "\n".join(out) + "\n"


def build_board(ledger, inbox_results, check_wait_results, wiki_queue, anomalies, now):
    red_total = len(ledger["red_pending"])
    yellow_total = len(ledger["yellow_pending"])
    anomaly_total = len(anomalies["items"])

    lines = []
    lines.append("---")
    lines.append("project: ClaudeEnv")
    lines.append("type: report")
    lines.append(f"generated: {now.strftime('%Y-%m-%dT%H:%M:%S')}")
    lines.append("tags:")
    lines.append("  - asa-board")
    lines.append("---")
    lines.append("")
    lines.append(f"# ☀️ 朝ボード — {now.strftime('%Y-%m-%d %H:%M')} 生成")
    lines.append("")
    lines.append("> [!warning] このページは自動生成・手書き禁止。裁定・メモは [[asa-items]] へ")
    lines.append("")

    # 🔴 要決定
    lines.append("## 🔴 要決定（3 分）")
    lines.append("")
    shown = ledger["red_pending"][:3]
    lines.append(render_table(ledger["red_header"], shown))
    if red_total > 3:
        lines.append(f"\n他 {red_total - 3} 件は翌日以降（台帳参照）\n")
    lines.append("")

    # 🟡 自動採択予定
    lines.append("## 🟡 自動採択予定（5 分・嫌なものだけ ❌）")
    lines.append("")
    y_header = ledger["yellow_header"]
    y_idx = col_index(y_header, "採択予定日")
    y_rows = ledger["yellow_pending"]
    if y_rows:
        badge_header = y_header + ["状態"]
        badge_rows = []
        today = now.date()
        for row in y_rows:
            badge = ""
            if 0 <= y_idx < len(row):
                m = re.match(r"^(\d{4}-\d{2}-\d{2})", row[y_idx].strip())
                if m:
                    try:
                        d = datetime.strptime(m.group(1), "%Y-%m-%d").date()
                        if d <= today:
                            badge = "⏰ 期限到来 → 次セッションで実行予定"
                    except ValueError:
                        pass
            badge_rows.append(row + [badge])
        lines.append(render_table(badge_header, badge_rows))
    else:
        lines.append("（該当なし）\n")
    lines.append("")

    # 🟠 異常
    lines.append("## 🟠 異常（2 分）")
    lines.append("")
    if anomalies["mode"] == "unavailable":
        lines.append("🟠 異常: 判定は SessionStart 注入を参照（自動化は v2）")
    elif anomaly_total == 0:
        lines.append("なし ✅")
    else:
        for item in anomalies["items"]:
            lines.append(f"- {item}")
    lines.append("")

    # 📥 未仕分けの受信箱
    lines.append("## 📥 未仕分けの受信箱（私が次セッションで仕分ける層）")
    lines.append("")
    inbox_total = sum(r["count"] for r in inbox_results)
    kk_total = sum(r["count"] for r in check_wait_results)
    wq_total = wiki_queue["count"] if wiki_queue else 0
    lines.append("| 面 | 件数 | ファイル数 |")
    lines.append("|---|---|---|")
    lines.append(f"| INBOX 🔵 未処理（行数・複数行で1案件のことあり） | {inbox_total} | {len(inbox_results)} |")
    lines.append(f"| ✅待ちマーカー | {kk_total} | {len(check_wait_results)} |")
    lines.append(f"| wiki 取り込みキュー未処理 | {wq_total} | {'1' if wiki_queue else '0'} |")
    lines.append("")

    def wikilink(f: Path):
        return f"[[{f.stem}]]"

    lines.append("<details>")
    lines.append("<summary>INBOX 🔵 内訳</summary>")
    lines.append("")
    for r in inbox_results:
        lines.append(f"- {wikilink(r['file'])} — {r['count']} 件")
        for l in r["lines"][:5]:
            lines.append(f"  - {l}")
    lines.append("")
    lines.append("</details>")
    lines.append("")
    lines.append("<details>")
    lines.append("<summary>✅待ちマーカー 内訳</summary>")
    lines.append("")
    for r in check_wait_results:
        lines.append(f"- {wikilink(r['file'])} — {r['count']} 件")
        for l in r["lines"][:5]:
            lines.append(f"  - {l}")
    lines.append("")
    lines.append("</details>")
    lines.append("")
    if wiki_queue:
        lines.append("<details>")
        lines.append("<summary>wiki 取り込みキュー 内訳</summary>")
        lines.append("")
        lines.append(f"- {wikilink(wiki_queue['file'])} — {wiki_queue['count']} 件")
        for l in wiki_queue["lines"][:10]:
            lines.append(f"  - {l}")
        lines.append("")
        lines.append("</details>")
        lines.append("")

    # 🟢 直近の単独実行記録
    lines.append("## 🟢 直近の単独実行記録")
    lines.append("")
    lines.append(render_table(ledger["green_header"], ledger["green_recent"]))
    lines.append("")

    # 🩺 スキャン健全性
    lines.append("## 🩺 スキャン健全性（正直表示）")
    lines.append("")
    lines.append(f"- 実行時刻: {now.strftime('%Y-%m-%d %H:%M:%S')}")
    lines.append(f"- 走査ファイル数: {scanned_file_count}")
    if read_failures:
        lines.append(f"- 読込失敗: {len(read_failures)} 件 — " + ", ".join(read_failures))
    else:
        lines.append("- 読込失敗: 0 件")
    lines.append(f"- パース警告: {parse_warnings} 件")
    if wiki_queue is None:
        lines.append("- wiki 取り込みキュー: 見つからず（スキップ）")
    lines.append("- このボードが拾えない面: 会話内バックログ・repo 側 tasks/*.md（従来どおり手動）")
    lines.append("")

    summary_line = f"SUMMARY 🔴{red_total} 🟡{yellow_total} 🟠{anomaly_total}"

    return "\n".join(lines) + "\n", summary_line


def main():
    now = datetime.now()

    ledger = load_ledger()
    if ledger is None:
        sys.stderr.write(f"[asa-board-gen] 台帳が読めません: {LEDGER}\n")
        sys.stderr.write("ボードは更新しません（旧版を保持）。\n")
        return 1

    inbox_results = scan_inboxes()
    check_wait_results = scan_check_wait()
    wiki_queue = scan_wiki_queue()
    anomalies = scan_anomalies()

    board_text, summary_line = build_board(
        ledger, inbox_results, check_wait_results, wiki_queue, anomalies, now
    )

    tmp_path = BOARD.with_suffix(".md.tmp")
    tmp_path.write_text(board_text, encoding="utf-8")
    os.replace(tmp_path, BOARD)

    print(summary_line)
    return 0


if __name__ == "__main__":
    sys.exit(main())
