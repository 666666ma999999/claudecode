#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""hantei_apply.py — 承認カード✅/❌/⏸裁定の後処理を1コマンド化する適用装置。

人の✅/❌/⏸判断はそのまま（判断ロジックは持たない）。事務（記帳→📒転記）だけを
自動化する。対象は `adscrm-biweekly-ads-pdca-result.md` / `adscrm-weekly-ops-review-result.md`
の承認カード（`[!todo]` callout の「あなたの返事」行）。

設計裁定（2026-07-11 team-lead）:
  1. `tasks/NOW.md` は MASA.local に実在しない（masa-2 側が正本の可能性）ため自動書込は行わない。
     カード見出しに M番号が明記されている場合のみ `tasks/mN-*.md` Metadata Status 更新の
     **提案**を出力するに留める（書込なし・Q→M自動対応表は作らない）。
  2. `interventions.csv` は既定では新規作成しない。ファイルが既にあれば追記するが、
     不在の場合は `--create-csv` を明示した時のみ docs/pdca-data-scheme.md のスキーマで
     新規作成する。ID形式は同docsの `i-YYYY-NNN` を既定とし、レポート実例の
     `M{n}-{YYYYMMDD}` 形式との食い違いを都度警告する。

Codex 敵対レビュー NO-GO 修正（2026-07-11）:
  HIGH1 冪等キーの再設計: 「Q/M番号（無ければ正規化した対象名）＋レポート期間
    （frontmatter window_end/generated_at、無ければファイル mtime 日付）＋回答セル正規化」。
    見出しの説明文が変わっても同一裁定として扱う。
  HIGH1' 出力先自己照合: state（journal）が壊れていても、追記直前に出力先自身
    （INBOX本文 / interventions.csv）を照合し、同一キーのマーカーが既にあれば skip。
    state はあくまで監査ログで、dedupe の一次ソースではない。
  HIGH2 部分失敗の一貫性: state を pending → inbox_done → csv_done → done の
    ジャーナル型にし、途中失敗時は不足分だけ次回 apply で補完する。
  HIGH3 並行編集の上書き防止: INBOX 読取直後にhashを保持し、atomic置換直前に
    再読して一致確認。不一致なら何も書かず fail-close。
  MEDIUM4 機械アンカー: 生成する各行の末尾に `<!-- hantei:<key> -->` を埋め込み、
    見出し文言の一致に頼らず自己照合できるようにした。
  MEDIUM5 CSV堅牢化: 既存ヘッダーの完全一致検証、新IDは当年の既存 `i-YYYY-NNN`
    最大連番+1（総行数からの採番は欠番/削除で衝突するため廃止）。書込前に
    書込可否（os.access）も確認する。

既定は dry-run（`--apply` を付けない限り一切書き込まない）。python3 標準ライブラリのみ。

usage:
  hantei_apply.py [report.md ...] [--apply] [--create-csv]
                   [--inbox PATH] [--csv PATH] [--tasks-dir PATH] [--state PATH]
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import io
import json
import os
import re
import sys
import tempfile
import time
import unicodedata
from datetime import date

HOME = os.path.expanduser("~")
VAULT = os.path.join(HOME, "Documents", "Obsidian Vault")
ADSCRM_DIR = os.path.join(VAULT, "02_Ai", "AI_adscrm", "AIads")

DEFAULT_REPORTS = [
    os.path.join(ADSCRM_DIR, "reports", "_ai", "adscrm-biweekly-ads-pdca-result.md"),
    os.path.join(ADSCRM_DIR, "reports", "_ai", "adscrm-weekly-ops-review-result.md"),
]
DEFAULT_INBOX = os.path.join(ADSCRM_DIR, "prompts", "AIads_INBOX.md")
DEFAULT_REPO = os.path.join(HOME, "Desktop", "prm", "prime_suite", "prime_ad")
DEFAULT_CSV = os.path.join(DEFAULT_REPO, "metrics", "interventions.csv")
DEFAULT_TASKS_DIR = os.path.join(DEFAULT_REPO, "tasks")

STATE_DIR = os.path.join(HOME, ".claude", "state")
DEFAULT_STATE = os.path.join(STATE_DIR, "hantei-apply.jsonl")

VERDICT_SYMBOLS = ["✅", "❌", "⏸"]

ANSWER_ROW_RE = re.compile(r"^\|\s*\*\*あなたの返事\*\*\s*\|\s*(.+?)\s*\|\s*$")
Q_RE = re.compile(r"[（(]?Q(\d{1,2})[）)]?")
M_RE = re.compile(r"\bM(\d{1,3})\b")
FRONTMATTER_WINDOW_END_RE = re.compile(r"^window_end:\s*(.+)$")
FRONTMATTER_GENERATED_AT_RE = re.compile(r"^generated_at:\s*(.+)$")

INBOX_LOG_HEADING = "## ✅ 裁定ログ（1行1裁定・新しい順・ボードの窓に映る）"
INBOX_NOTE_ANCHOR = "裁定原文もここへ"
INBOX_ENTRIES_HEADER = "**裁定原文（カード回答・自動記帳 by hantei_apply.py）**"

# MEDIUM4: 見出し文言依存を排除する機械アンカー。初回 --apply 時に1度だけ設置し、
# 以後はこのアンカー（一意性検証つき）を基準に挿入位置を特定する。
INBOX_LOG_ANCHOR = "<!-- hantei-log -->"
INBOX_ENTRIES_ANCHOR = "<!-- hantei-entries -->"

CSV_HEADER = [
    "intervention_id", "executed_at", "media", "level", "target_id",
    "target_name", "action", "hypothesis", "expected_metric",
    "review_start", "review_end", "owner", "note",
]


def marker(key):
    return "<!-- hantei:%s -->" % key


# --- I/O helpers -----------------------------------------------------------

def read_text(path):
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


def sha256_text(text):
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def atomic_write(path, text):
    """temp file + os.replace で原子的に差し替え（wiki_ingest_apply.py と同型）。"""
    d = os.path.dirname(path)
    fd, tmp = tempfile.mkstemp(dir=d, prefix=".hantei-apply-", suffix=".tmp")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(text)
            f.flush()
            os.fsync(f.fileno())
        os.replace(tmp, path)
    except BaseException:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


def now_iso():
    return time.strftime("%Y-%m-%dT%H:%M:%S%z")


def journal(path, record):
    """state（監査ログ・dedupe の一次ソースではない）へ1行追記 + fsync。"""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    rec = dict(record)
    rec.setdefault("ts", now_iso())
    with open(path, "a", encoding="utf-8") as f:
        f.write(json.dumps(rec, ensure_ascii=False) + "\n")
        f.flush()
        os.fsync(f.fileno())


# --- report parsing ---------------------------------------------------------

def strip_quote(ln):
    if ln.startswith(">"):
        ln = ln[1:]
    if ln.startswith(" "):
        ln = ln[1:]
    return ln


def extract_callout_runs(text):
    """連続する `>` 始まりの行のかたまり(1 callout = 1 run)を切り出す。"""
    runs = []
    cur = []
    for ln in text.splitlines():
        if ln.startswith(">"):
            cur.append(ln)
        else:
            if cur:
                runs.append(cur)
                cur = []
    if cur:
        runs.append(cur)
    return runs


def parse_answer_cell(cell):
    """回答セルを判定する。プレースホルダー（未回答）なら None を返す。

    契約: セル内に✅/❌/⏸のうち distinct な記号がちょうど1種類だけ現れる
    場合のみ「回答済み」とみなす。テンプレのプレースホルダーは
    `✅ / ❌ / ⏸` や `✅（現状維持を承認）/ ❌` のように複数記号を選択肢
    として列挙するため distinct >= 2 になり、未回答として skip される。
    """
    found = [s for s in VERDICT_SYMBOLS if s in cell]
    distinct = set(found)
    if len(distinct) != 1:
        return None
    symbol = found[0]
    idx = cell.find(symbol)
    rest = cell[idx + len(symbol):].strip()
    return symbol, rest, cell.strip()


def parse_heading(raw_heading):
    """callout見出し(`[!todo] ` の後ろ)から対象ラベル・Q番号・M番号を抽出する。"""
    h = raw_heading.strip()
    h = re.sub(r"^\d+\.\s*", "", h)          # 先頭の "1. " 等
    h = re.sub(r"^【[^】]*】", "", h).strip()  # 先頭の "【最優先】" 等

    q = None
    qm = Q_RE.search(h)
    if qm:
        q = int(qm.group(1))

    m = None
    mm = M_RE.search(h)
    if mm:
        m = int(mm.group(1))

    label = re.split(r"[—\-]{1,2}\s", h)[0]
    label = re.split(r"[〔(（]", label)[0].strip()
    if not label:
        label = h

    return label, q, m, h


def normalize_ws(s):
    s = unicodedata.normalize("NFKC", s)
    return re.sub(r"\s+", " ", s).strip()


def report_period(path, text):
    """frontmatter の window_end（優先）/generated_at からレポート期間を得る。
    frontmatter が無い/読めない場合はファイル mtime の日付にフォールバック。"""
    lines = text.splitlines()
    if lines and lines[0].strip() == "---":
        window_end = None
        generated_at = None
        for ln in lines[1:60]:
            if ln.strip() == "---":
                break
            m1 = FRONTMATTER_WINDOW_END_RE.match(ln.strip())
            if m1:
                window_end = m1.group(1).strip().strip('"')
            m2 = FRONTMATTER_GENERATED_AT_RE.match(ln.strip())
            if m2:
                generated_at = m2.group(1).strip().strip('"')
        if window_end:
            return window_end
        if generated_at:
            return generated_at
    try:
        return time.strftime("%Y-%m-%d", time.localtime(os.path.getmtime(path)))
    except OSError:
        return "unknown-period"


def parse_report(text, report_name, report_path):
    period = report_period(report_path, text)
    cards = []
    for run in extract_callout_runs(text):
        content = [strip_quote(l) for l in run]
        if not content:
            continue
        first = content[0].strip()
        m = re.match(r"^\[!todo\]\s*(.*)$", first)
        if not m:
            continue
        heading_raw = m.group(1)

        answer_cell = None
        for cl in content:
            am = ANSWER_ROW_RE.match(cl.strip())
            if am:
                answer_cell = am.group(1).strip()
                break
        if answer_cell is None:
            continue  # 承認行を持たないカード（月次定例タスク等）

        parsed = parse_answer_cell(answer_cell)
        if parsed is None:
            continue  # 未回答（プレースホルダーのまま）

        symbol, comment, raw_cell = parsed
        label, q, mnum, full_heading = parse_heading(heading_raw)

        entity_id = ("Q%d" % q) if q is not None else (("M%d" % mnum) if mnum is not None else normalize_ws(label))
        key_material = "%s|%s|%s" % (entity_id, period, normalize_ws(raw_cell))
        key = sha256_text(key_material)[:16]

        cards.append({
            "report_name": report_name,
            "period": period,
            "entity_id": entity_id,
            "full_heading": full_heading,
            "label": label,
            "q": q,
            "m": mnum,
            "symbol": symbol,
            "comment": comment,
            "raw_cell": raw_cell,
            "key": key,
        })
    return cards


# --- 出力先自己照合（dedupe の一次ソース） -----------------------------------

def inbox_has_key(text, key):
    return marker(key) in text


def csv_has_key(text, key):
    return ("key=%s" % key) in text


# --- INBOX edits -------------------------------------------------------------

def _label_part(c):
    tag = ""
    if c["q"] is not None:
        tag = "Q%d" % c["q"]
    elif c["m"] is not None:
        tag = "M%d" % c["m"]
    if tag and tag not in c["label"]:
        return "%s%s" % (tag, c["label"])
    return c["label"]


def build_log_line(c, today_str, short_date):
    comment = c["comment"] if c["comment"] else c["symbol"]
    return "- %s %s %s=%s — 全文は📒 %s %s" % (
        today_str, c["symbol"], _label_part(c), comment, short_date, marker(c["key"]),
    )


def build_toroku_bullet(c, today_str):
    tags = []
    if c["q"] is not None:
        tags.append("Q%d" % c["q"])
    if c["m"] is not None:
        tags.append("M%d" % c["m"])
    tags = [t for t in tags if t not in c["label"]]
    tag = "・".join(tags)
    target_disp = "%s（%s）" % (c["label"], tag) if tag else c["label"]
    return "- %s ｜ %s ｜ %s ｜ %s %s" % (
        today_str, target_disp, c["symbol"], c["raw_cell"], marker(c["key"]),
    )


def _find_unique_anchor(lines, anchor_text):
    """アンカー行を一意性検証つきで探す。複数存在したら壊れているとみなし例外。"""
    idxs = [i for i, ln in enumerate(lines) if ln.strip() == anchor_text]
    if len(idxs) > 1:
        raise RuntimeError(
            "INBOX にアンカー「%s」が複数存在（一意性違反・手動確認が必要）" % anchor_text)
    return idxs[0] if idxs else None


def insert_hantei_log_lines(text, log_lines):
    """裁定ログ見出し直下へ新しい順で追記。挿入位置は機械アンカー
    `<!-- hantei-log -->` を基準にし、初回のみ見出し文言から探して1度だけ設置する。"""
    lines = text.split("\n")
    anchor_idx = _find_unique_anchor(lines, INBOX_LOG_ANCHOR)

    if anchor_idx is None:
        idx_heading = None
        for i, ln in enumerate(lines):
            if ln.strip() == INBOX_LOG_HEADING:
                idx_heading = i
                break
        if idx_heading is None:
            raise RuntimeError("INBOX に見出し「%s」もアンカーも見つからない" % INBOX_LOG_HEADING)
        insert_at = idx_heading + 1
        while insert_at < len(lines) and (
            lines[insert_at].strip() == "" or lines[insert_at].strip().startswith("<!--")
        ):
            insert_at += 1
        lines.insert(insert_at, INBOX_LOG_ANCHOR)
        anchor_idx = insert_at

    insert_at = anchor_idx + 1
    for ln in reversed(log_lines):
        lines.insert(insert_at, ln)
    return "\n".join(lines)


def insert_toroku_bullets(text, bullets):
    """📒 裁定原文セクションへ追記。挿入位置は機械アンカー `<!-- hantei-entries -->`
    を基準にし、初回のみ運用ノート文言から探して1度だけ設置する。"""
    lines = text.split("\n")
    anchor_idx = _find_unique_anchor(lines, INBOX_ENTRIES_ANCHOR)

    if anchor_idx is None:
        header_idx = None
        for i, ln in enumerate(lines):
            if ln.strip() == INBOX_ENTRIES_HEADER:
                header_idx = i
                break
        if header_idx is not None:
            lines.insert(header_idx + 1, INBOX_ENTRIES_ANCHOR)
            anchor_idx = header_idx + 1
        else:
            note_idx = None
            for i, ln in enumerate(lines):
                if INBOX_NOTE_ANCHOR in ln:
                    note_idx = i
                    break
            if note_idx is None:
                raise RuntimeError("INBOX に📒運用ノート（'%s'）もアンカーも見つからない" % INBOX_NOTE_ANCHOR)
            j = note_idx
            while j < len(lines) and lines[j].strip().startswith(">"):
                j += 1
            block = ["", INBOX_ENTRIES_HEADER, INBOX_ENTRIES_ANCHOR]
            lines[j:j] = block
            anchor_idx = j + 2

    insert_at = anchor_idx + 1
    for b in reversed(bullets):
        lines.insert(insert_at, b)
    return "\n".join(lines)


# --- interventions.csv -------------------------------------------------------

def read_csv_rows(path):
    with open(path, newline="", encoding="utf-8") as f:
        return list(csv.reader(f))


def validate_csv_header(rows):
    """既存csvのヘッダーが期待どおりか検証する。問題なければ None。"""
    if not rows:
        return "csv が空（ヘッダー行なし）"
    if rows[0] != CSV_HEADER:
        return "csv ヘッダー不一致（期待=%s / 実際=%s）" % (CSV_HEADER, rows[0])
    return None


def next_intervention_id(rows, year):
    """当年の既存 `i-YYYY-NNN` 最大連番+1。総行数からの採番は欠番/削除で衝突するため使わない。"""
    maxn = 0
    pat = re.compile(r"^i-%d-(\d+)$" % year)
    for row in rows[1:]:
        if not row:
            continue
        m = pat.match(row[0])
        if m:
            maxn = max(maxn, int(m.group(1)))
    return maxn + 1


def csv_writable(path):
    """atomic_write は同ディレクトリに一時ファイルを作って rename するため、
    書込可否を左右するのは対象ファイル自身のパーミッションではなくディレクトリの書込権限。"""
    d = os.path.dirname(os.path.abspath(path)) or "."
    return os.path.isdir(d) and os.access(d, os.W_OK)


def build_csv_row(c, iid, today_dt):
    media = "meta" if re.search(r"meta", c["full_heading"], re.IGNORECASE) else "google"
    note = "hantei_apply.py 自動記帳（要目視確認: level/target_id/actionは未設定）｜ 裁定=%s ｜ 出典=%s ｜ key=%s" % (
        c["raw_cell"], c["report_name"], c["key"],
    )
    return [
        iid, today_dt.strftime("%Y-%m-%dT%H:%M"), media, "", "",
        c["label"], "", "", "", "", "", "masaaki", note,
    ]


def rows_to_csv_text(rows):
    buf = io.StringIO()
    w = csv.writer(buf)
    for r in rows:
        w.writerow(r)
    return buf.getvalue()


# --- main --------------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("reports", nargs="*", help="対象レポートのパス（省略時は隔週/週次の2ボードを自動走査）")
    ap.add_argument("--apply", action="store_true", help="実際に書き込む（既定はdry-run）")
    ap.add_argument("--create-csv", action="store_true",
                    help="interventions.csv が無い場合に docs スキーマで新規作成する（既定では作成しない）")
    ap.add_argument("--inbox", default=DEFAULT_INBOX)
    ap.add_argument("--csv", default=DEFAULT_CSV)
    ap.add_argument("--tasks-dir", default=DEFAULT_TASKS_DIR)
    ap.add_argument("--state", default=DEFAULT_STATE)
    args = ap.parse_args()

    reports = args.reports if args.reports else DEFAULT_REPORTS

    all_cards = []
    for rp in reports:
        if not os.path.isfile(rp):
            print("[skip] レポートが見つからない: %s" % rp)
            continue
        text = read_text(rp)
        cards = parse_report(text, os.path.basename(rp), rp)
        all_cards.extend(cards)

    if not os.path.isfile(args.inbox):
        print("[error] INBOX が見つからない: %s" % args.inbox)
        return 1

    inbox_text_initial = read_text(args.inbox)
    inbox_hash_initial = sha256_text(inbox_text_initial)

    csv_exists = os.path.isfile(args.csv)
    do_csv = csv_exists or args.create_csv
    csv_text_for_check = read_text(args.csv) if csv_exists else ""

    # --- 出力先自己照合でカードごとの現況を判定（stateではなく本文が正） ---
    for c in all_cards:
        c["inbox_present"] = inbox_has_key(inbox_text_initial, c["key"])
        c["csv_present"] = do_csv and csv_has_key(csv_text_for_check, c["key"])
        c["needs_inbox"] = not c["inbox_present"]
        c["needs_csv"] = do_csv and not c["csv_present"]

    need_inbox_cards = [c for c in all_cards if c["needs_inbox"]]
    need_csv_cards = [c for c in all_cards if c["needs_csv"]]
    fully_done = [c for c in all_cards if not c["needs_inbox"] and not c["needs_csv"]]

    print("=== hantei_apply: 検出 %d 件（INBOX未反映 %d ／ csv未反映 %d ／ 完全処理済 %d） ===" % (
        len(all_cards), len(need_inbox_cards), len(need_csv_cards) if do_csv else 0, len(fully_done)))
    for c in all_cards:
        status_bits = []
        if c["needs_inbox"]:
            status_bits.append("INBOX未反映")
        if do_csv and c["needs_csv"]:
            status_bits.append("csv未反映")
        status = "・".join(status_bits) if status_bits else "完全処理済(skip)"
        print("- [%s] %s | %s | %s: %s (key=%s)" % (
            status, c["report_name"], c["full_heading"], c["symbol"], c["raw_cell"], c["key"]))
        if c["m"] is not None and (c["needs_inbox"] or (do_csv and c["needs_csv"])):
            print("      -> [提案のみ・書込なし] tasks/m%d-*.md の Metadata Status 更新を検討してください" % c["m"])

    if not need_inbox_cards and not (do_csv and need_csv_cards):
        if not do_csv and not csv_exists:
            print("\n[interventions.csv] ファイル不在: %s" % args.csv)
            print("  masa-2 側が正本の可能性があるため、実行中のホストでは新規作成しません（--create-csv 未指定）。")
        print("\n新規裁定なし（全カード処理済み）。終了。")
        return 0

    today_dt = date.today()
    today_str = today_dt.isoformat()
    short_date = "%d/%d" % (today_dt.month, today_dt.day)

    log_lines = [build_log_line(c, today_str, short_date) for c in need_inbox_cards]
    bullets = [build_toroku_bullet(c, today_str) for c in need_inbox_cards]

    if need_inbox_cards:
        updated_inbox_text = insert_hantei_log_lines(inbox_text_initial, log_lines)
        updated_inbox_text = insert_toroku_bullets(updated_inbox_text, bullets)
        print("\n--- INBOX 追記プレビュー（裁定ログ） ---")
        for ln in log_lines:
            print(ln)
        print("\n--- INBOX 追記プレビュー（📒 裁定原文） ---")
        for b in bullets:
            print(b)
    else:
        updated_inbox_text = None
        print("\n[INBOX] 追記対象なし（全カード既に本文に記録済み）")

    csv_rows_new = []
    csv_header_err = None
    if do_csv and need_csv_cards:
        if csv_exists:
            existing_rows = read_csv_rows(args.csv)
            csv_header_err = validate_csv_header(existing_rows)
            next_id = next_intervention_id(existing_rows, today_dt.year) if csv_header_err is None else None
        else:
            existing_rows = [CSV_HEADER]
            next_id = 1
        if csv_header_err is None:
            n = next_id
            for c in need_csv_cards:
                iid = "i-%d-%03d" % (today_dt.year, n)
                n += 1
                csv_rows_new.append((c, build_csv_row(c, iid, today_dt)))
            print("\n--- interventions.csv 追記プレビュー%s ---" % ("" if csv_exists else "（新規作成）"))
            if not csv_exists:
                print(",".join(CSV_HEADER))
            for _, r in csv_rows_new:
                print(",".join(r))
            print("⚠️  ID形式は docs/pdca-data-scheme.md の `i-YYYY-NNN` を既定使用。"
                  "レポート実例は `M{n}-{YYYYMMDD}` 形式のため、実csvが別マシン(masa-2)に存在する場合は"
                  "初回apply前に実物のID列と照合すること。")
        else:
            print("\n[interventions.csv] ヘッダー検証エラー: %s" % csv_header_err)
            print("  csv 追記をスキップします（INBOX 側は影響を受けません）。")
    elif not do_csv:
        print("\n[interventions.csv] ファイル不在: %s" % args.csv)
        print("  masa-2 側が正本の可能性があるため、実行中のホストでは新規作成しません（--create-csv 未指定）。")
        print("  作成する場合は --create-csv を明示してください。")

    if not args.apply:
        print("\n[dry-run] 書込なし。適用するには --apply を付けてください。")
        return 0

    # --- pending journal（監査ログ。dedupeの一次ソースではない） ---
    for c in need_inbox_cards:
        journal(args.state, {"state": "pending", "key": c["key"], "step": "inbox", "report": c["report_name"]})
    for c, _ in csv_rows_new:
        journal(args.state, {"state": "pending", "key": c["key"], "step": "csv", "report": c["report_name"]})

    inbox_done_keys = set()
    csv_done_keys = set()

    # --- HIGH3: 並行編集検知（再読 → hash比較 → 不一致なら fail-close） ---
    if need_inbox_cards:
        inbox_text_recheck = read_text(args.inbox)
        if sha256_text(inbox_text_recheck) != inbox_hash_initial:
            print("\n[abort] INBOX が処理中に外部で変更されました（並行編集検知）。"
                  "何も書き込んでいません。もう一度 /hantei を実行してください。")
            return 1
        atomic_write(args.inbox, updated_inbox_text)
        print("\n[applied] INBOX 更新: %s" % args.inbox)
        for c in need_inbox_cards:
            journal(args.state, {"state": "inbox_done", "key": c["key"], "report": c["report_name"]})
            inbox_done_keys.add(c["key"])
    else:
        print("\n[applied] INBOX 変更なし（追記対象なし）")

    if do_csv and need_csv_cards:
        if csv_header_err is not None:
            print("[skipped] interventions.csv 追記: ヘッダー不一致のため中止（要手動確認）")
        elif not csv_writable(args.csv):
            print("[skipped] interventions.csv 追記: 書込不可（ディレクトリの書込権限が無い）。"
                  "解消後に再実行すれば不足分だけ補完されます。")
        else:
            try:
                new_row_texts = rows_to_csv_text([r for _, r in csv_rows_new])
                if csv_exists:
                    base_text = read_text(args.csv)
                    if not base_text.endswith("\n"):
                        base_text += "\n"
                    atomic_write(args.csv, base_text + new_row_texts)
                else:
                    header_text = rows_to_csv_text([CSV_HEADER])
                    os.makedirs(os.path.dirname(args.csv), exist_ok=True)
                    atomic_write(args.csv, header_text + new_row_texts)
            except OSError as e:
                print("[skipped] interventions.csv 追記: 書込失敗 (%s)。"
                      "解消後に再実行すれば不足分だけ補完されます。" % e)
            else:
                print("[applied] interventions.csv 追記: %s (%d行%s)" % (
                    args.csv, len(csv_rows_new), "・新規作成" if not csv_exists else ""))
                for c, _ in csv_rows_new:
                    journal(args.state, {"state": "csv_done", "key": c["key"], "report": c["report_name"]})
                    csv_done_keys.add(c["key"])

    # --- done journal（出力先自己照合 or 今回の実書込が両方揃ったカードのみ） ---
    for c in all_cards:
        if not (c["needs_inbox"] or c["needs_csv"]):
            continue  # 今回作業対象外（既に完全処理済）
        inbox_ok = c["inbox_present"] or c["key"] in inbox_done_keys
        csv_ok = (not do_csv) or c["csv_present"] or c["key"] in csv_done_keys
        if inbox_ok and csv_ok:
            journal(args.state, {"state": "done", "key": c["key"], "report": c["report_name"]})

    print("[state] 監査ログ: %s" % args.state)
    return 0


if __name__ == "__main__":
    sys.exit(main())
