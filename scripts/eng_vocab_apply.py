#!/usr/bin/env python3
"""eng_vocab_apply.py — runner の出力を vault に反映する柵（書き込みはここだけ）

入力: runner が保存した result md（引数1）
やること:
 1. 出力中の「## 週次セクション」部分を 00_Inbox/LvEng_単語帳.md の先頭（frontmatter直後）に prepend
 2. ```json eng-vocab-fills``` フェンスの [{"word","translation"}] を LvEng_nhk.md の
    該当行（訳が空欄の行）に「　訳」として追記（既存文字は一切変更しない・該当行が見つからない場合はスキップ）
安全策: 置換ではなく行末追記のみ / 対象行に日本語が既にあればスキップ / バックアップを state に保存
"""
import json, os, re, shutil, sys
from datetime import datetime

HOME = os.path.expanduser("~")
MEMO = os.path.join(HOME, "Documents/Obsidian Vault/00_Inbox/LvEng_nhk.md")
BOOK = os.path.join(HOME, "Documents/Obsidian Vault/00_Inbox/LvEng_単語帳.md")
STATE = os.path.join(HOME, ".claude/state/eng-vocab")
JP = re.compile(r"[ぁ-んァ-ン一-龥]")

BOOK_HEADER = """---
project: general
type: log
folder: "00_Inbox/"
tags:
  - english
  - vocab
---

# 📚 英単語帳（週次自動生成 + 手書きメモ統合）

> 毎週日曜朝に自動更新。源泉 = ①Chrome の「◯◯ 意味」検索（直近7日） ②手書きメモ [[LvEng_nhk]]。
> 冒頭の復習5問は先週・先々週の単語からランダム。答えは折りたたみの中。

"""

def main():
    if len(sys.argv) < 2 or not os.path.exists(sys.argv[1]):
        print("usage: eng_vocab_apply.py <runner-result.md>", file=sys.stderr)
        sys.exit(2)
    result = open(sys.argv[1], encoding="utf-8").read()

    # --- 1. 週次セクションを単語帳へ prepend ---
    m = re.search(r"(## 📅 .*?)(?=```json eng-vocab-fills|\Z)", result, re.S)
    section = m.group(1).rstrip() + "\n\n---\n\n" if m else None
    if section:
        if os.path.exists(BOOK):
            body = open(BOOK, encoding="utf-8").read()
            fm = re.match(r"^---\n.*?\n---\n", body, re.S)
            if fm:
                head, rest = body[: fm.end()], body[fm.end():]
                # 見出し+説明ブロックの後に挿す（最初の --- 区切り or 直後）
                new = head + rest.split("\n", 0)[0] if False else head + rest
                # 先頭の固定説明（# 見出し〜最初の空行2つ）を保ったまま、その直後に prepend
                parts = re.split(r"(\n---\n)", rest, maxsplit=0)
                new = head + rest
                # シンプルに: 固定ヘッダの終わり = 最初の "> 冒頭の…" 行の後の空行
                anchor = re.search(r"\n\n(?=## |\Z)", rest)
                if anchor:
                    new = head + rest[: anchor.start() + 2] + section + rest[anchor.start() + 2:]
                else:
                    new = head + rest + "\n" + section
            else:
                new = body + "\n" + section
        else:
            new = BOOK_HEADER + section
        os.makedirs(STATE, exist_ok=True)
        if os.path.exists(BOOK):
            shutil.copy2(BOOK, os.path.join(STATE, "book.bak"))
        open(BOOK, "w", encoding="utf-8").write(new)
        print("[ok] 単語帳に週次セクションを追加")
    else:
        print("[warn] 週次セクション(## 📅)が result に見つからない", file=sys.stderr)

    # --- 2. メモの空欄埋め ---
    fm2 = re.search(r"```json eng-vocab-fills\n(.*?)\n```", result, re.S)
    if not fm2:
        print("[info] fills なし")
        return
    try:
        fills = json.loads(fm2.group(1))
    except Exception as e:
        print(f"[warn] fills JSON parse 失敗: {e}", file=sys.stderr)
        return
    if not os.path.exists(MEMO):
        return
    shutil.copy2(MEMO, os.path.join(STATE, "memo.bak"))
    lines = open(MEMO, encoding="utf-8").read().splitlines(keepends=False)
    filled = 0
    for f in fills:
        w, t = (f.get("word") or "").strip(), (f.get("translation") or "").strip()
        if not w or not t:
            continue
        for i, line in enumerate(lines):
            if line.strip().lower() == w.lower() and not JP.search(line):
                lines[i] = line + "　" + t
                filled += 1
                break
    open(MEMO, "w", encoding="utf-8").write("\n".join(lines) + "\n")
    print(f"[ok] メモ空欄埋め {filled} 件")

if __name__ == "__main__":
    main()
