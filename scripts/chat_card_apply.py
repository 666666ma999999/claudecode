#!/usr/bin/env python3
"""chat_card_apply.py — runner の出力を承認INBOX（vault）へ反映し、要対応があれば macOS 通知（柵）

- 入力: runner result md（引数1）
- カード（### 🃏 …）があれば 00_Inbox/承認INBOX.md の今日のセクションに追記
- 追記した要対応件数 >0 のときだけ osascript で通知（空なら無音）
"""
import json, os, re, subprocess, sys
from datetime import datetime

HOME = os.path.expanduser("~")
INBOX = os.path.join(HOME, "Documents/Obsidian Vault/00_Inbox/承認INBOX.md")
AUDIT = os.path.join(HOME, "Documents/Obsidian Vault/00_Inbox/chat-reports/chat-cards-audit.md")
STATE_DIR = os.path.join(HOME, ".claude/state/chat-cards")
WORKLIST = os.path.join(STATE_DIR, "worklist.json")
LAST_RUN_F = os.path.join(STATE_DIR, "last_run.txt")
CANDIDATE_F = os.path.join(STATE_DIR, "last_run_candidate.txt")

AUDIT_HEADER = """---
project: general
type: log
folder: "00_Inbox/chat-reports/"
tags:
  - chat-cards
  - audit
---

# 🩺 chat-cards 監査ログ（毎時・ハートビート兼用）

> 毎回の実行結果1行＋情報のみの内訳。**このファイルの更新時刻が生存確認**（丸1日止まると
> collector-health の成果物監視が🔴を出す）。「情報のみ」への誤落ち（見逃し）はここで抜き打ち確認する。

"""


def commit_last_run():
    """柵の最終段: apply まで成功した時だけ観測窓を前進（commit-on-success）"""
    if os.path.exists(CANDIDATE_F):
        os.replace(CANDIDATE_F, LAST_RUN_F)


def append_audit(stamp, n_expected, n_cards, kinds_summary, warn, info):
    """毎実行1エントリを監査ログへ prepend。0件でも書く＝ハートビート"""
    entry = f"- **{stamp}** 入力{n_expected}・カード{n_cards}（{kinds_summary}）"
    if warn:
        entry += f" {warn}"
    entry += "\n"
    if info:
        for line in info.splitlines()[1:]:  # 見出し行を除く
            if line.strip():
                entry += f"    {line.strip()}\n"
    if os.path.exists(AUDIT):
        body = open(AUDIT, encoding="utf-8").read()
        m = re.search(r"(?m)^- \*\*", body)  # 最初のエントリ行の直前に挿入（新しい順）
        head, rest = (body[: m.start()], body[m.start():]) if m else (body, "")
        lines = (entry + rest).splitlines(keepends=True)
        new = head + "".join(lines[:400])  # 直近分だけ保持（肥大防止）
    else:
        new = AUDIT_HEADER + entry
    os.makedirs(os.path.dirname(AUDIT), exist_ok=True)
    open(AUDIT, "w", encoding="utf-8").write(new)


def coverage_warning(result, n_cards):
    """件数照合: 入力全件がカード/情報のみに計上されているか（見逃しリスクの柵）"""
    try:
        expected = len(json.load(open(WORKLIST))["items"])
    except Exception:
        return None
    m = re.search(r"件数照合[:：]\s*入力(\d+)\S*\s*=\s*カード(\d+)\S*\s*\+\s*情報のみ(\d+)", result)
    if not m:
        return f"⚠️ 件数照合行なし（入力{expected}件・カード{n_cards}枚 — 見逃しの可能性）"
    n_in, n_c, n_info = map(int, m.groups())
    if n_in != expected or n_c + n_info != n_in or n_c != n_cards:
        return f"⚠️ 件数不一致: 実入力{expected} / 申告 入力{n_in}=カード{n_c}+情報{n_info}（実カード{n_cards}）"
    return None

HEADER = """---
project: general
type: ops
folder: "00_Inbox/"
tags:
  - approval
  - chat-cards
---

# 🃏 承認INBOX — Chat の要対応カード（毎時自動・空振りは無音）

> 使い方: カードを読んで ✅承認 / ❌却下 / ✍️自分で対応 / ⏸保留 を心で決め、**返信は Chat 上であなたが送る**（下書きはコピペ用）。
> 処理済みカードは行ごと消してOK（正本は Chat 側）。裁定を記録したい時だけ `/hantei`。

"""

def notify(title, msg):
    try:
        subprocess.run(["osascript", "-e",
                        f'display notification "{msg}" with title "{title}" sound name "Glass"'],
                       timeout=10)
    except Exception:
        pass

def main():
    if len(sys.argv) < 2 or not os.path.exists(sys.argv[1]):
        print("usage: chat_card_apply.py <runner-result.md>", file=sys.stderr)
        sys.exit(2)
    result = open(sys.argv[1], encoding="utf-8").read()

    # runner の frontmatter/前置きの後ろから本文カードを拾う
    cards = re.findall(r"(### 🃏 .*?)(?=\n### |\Z)", result, re.S)
    info = re.search(r"### 📄 情報のみ.*", result, re.S)
    n = len(cards)
    warn = coverage_warning(result, n)
    try:
        expected = len(json.load(open(WORKLIST))["items"])
    except Exception:
        expected = -1
    stamp = datetime.now().strftime("%m/%d %H:%M")

    if n == 0 and not warn:
        append_audit(stamp, expected, 0, "要対応なし", None, info.group(0) if info else "")
        commit_last_run()
        print("[ok] カード0件（無音・監査ログ更新）")
        return

    block = f"\n## ⏰ {stamp}（{n}件）\n\n"
    if warn:
        block += f"> [!warning] {warn}\n\n"
    if cards:
        block += "\n\n".join(c.strip() for c in cards) + "\n"
    if info:
        block += "\n" + info.group(0).strip() + "\n"

    if os.path.exists(INBOX):
        body = open(INBOX, encoding="utf-8").read()
        fm = re.match(r"^---\n.*?\n---\n", body, re.S)
        anchor = re.search(r"\n\n(?=## ⏰|\Z)", body[fm.end():] if fm else body)
        if fm and anchor:
            head = body[: fm.end()]
            rest = body[fm.end():]
            new = head + rest[: anchor.start() + 2] + block + rest[anchor.start() + 2:]
        else:
            new = body + block
    else:
        new = HEADER + block
    open(INBOX, "w", encoding="utf-8").write(new)

    kinds = re.findall(r"### 🃏 \[?(要承認|要返信|判定不能)\]?", result)  # 括弧ゆれ許容(2026-07-18実出力)
    summary = f"要承認{kinds.count('要承認')}・要返信{kinds.count('要返信')}・判定不能{kinds.count('判定不能')}"
    if warn:
        summary += " ⚠️照合NG"
    append_audit(stamp, expected, n, summary, warn, info.group(0) if info else "")
    commit_last_run()
    notify("🃏 承認カード", f"{summary} — 承認INBOXへ")
    print(f"[ok] {n}件追記 + 通知（{summary}）" + (f" {warn}" if warn else ""))

if __name__ == "__main__":
    main()
