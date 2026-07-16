#!/usr/bin/env python3
"""eng_vocab_extract.py — 週次英単語帳の入力材料を作る（決定論パート・柵の前段）

1. Chrome 全プロファイルの History(sqlite) をコピーして開き、直近7日の
   Google 検索クエリから「英単語の意味調べ」(例: "mitigate 意味", "reassure とは") を抽出
2. vault の手書きメモ 00_Inbox/LvEng_nhk.md から「訳が空欄の行」を抽出
3. ~/.claude/state/eng-vocab/worklist.json に書き出す（runner プロンプトが Read する）

本人許可: 履歴の利用は 2026-07-14 に全期間・集計目的で許可済み。ここでは単語クエリのみ抽出。
"""
import json, os, re, shutil, sqlite3, sys, tempfile, time
from datetime import datetime, timedelta

HOME = os.path.expanduser("~")
CHROME = os.path.join(HOME, "Library/Application Support/Google/Chrome")
PROFILES = ["Default", "Profile 1", "Profile 2", "Profile 3", "Profile 4"]
MEMO = os.path.join(HOME, "Documents/Obsidian Vault/00_Inbox/LvEng_nhk.md")
OUT_DIR = os.path.join(HOME, ".claude/state/eng-vocab")
OUT = os.path.join(OUT_DIR, "worklist.json")

# Chrome epoch (1601-01-01) -> unix
def chrome_time(dt):
    return int((dt - datetime(1601, 1, 1)).total_seconds() * 1_000_000)

WORD_Q = re.compile(r"^([a-zA-Z][a-zA-Z \-']{1,40}?)\s*(?:の)?(?:意味|とは|訳|和訳|日本語)$")
JP = re.compile(r"[ぁ-んァ-ン一-龥]")

def extract_history_words(days=7):
    words = {}
    since = chrome_time(datetime.utcnow() - timedelta(days=days))
    for prof in PROFILES:
        db = os.path.join(CHROME, prof, "History")
        if not os.path.exists(db):
            continue
        with tempfile.NamedTemporaryFile(suffix=".db", delete=False) as tf:
            tmp = tf.name
        try:
            shutil.copy2(db, tmp)
            con = sqlite3.connect(tmp)
            cur = con.execute(
                "SELECT url, last_visit_time FROM urls "
                "WHERE last_visit_time > ? AND (url LIKE '%google.%/search?%' OR url LIKE '%google.%/search%q=%')",
                (since,),
            )
            from urllib.parse import urlparse, parse_qs, unquote_plus
            for url, _ in cur.fetchall():
                q = parse_qs(urlparse(url).query).get("q", [""])[0]
                q = unquote_plus(q).strip()
                m = WORD_Q.match(q)
                if m:
                    w = m.group(1).strip().lower()
                    words[w] = words.get(w, 0) + 1
            con.close()
        except Exception as e:
            print(f"[warn] {prof}: {e}", file=sys.stderr)
        finally:
            os.unlink(tmp)
    return sorted(words.keys())

def extract_memo_blanks():
    """訳の無い行 = ASCII 単語だけで日本語を含まない行（見出し・空行・記号行は除外）"""
    blanks, recent_all = [], []
    if not os.path.exists(MEMO):
        return blanks, recent_all
    for line in open(MEMO, encoding="utf-8"):
        s = line.strip()
        if not s or s.startswith(("#", "(", "//", "-", ">")):
            continue
        recent_all.append(s)
        if not JP.search(s) and re.match(r"^[a-zA-Z][a-zA-Z \-'\.]*$", s):
            blanks.append(s)
    return blanks, recent_all[-60:]  # 復習プール用に直近60行も渡す

def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    hist = extract_history_words()
    blanks, memo_recent = extract_memo_blanks()
    payload = {
        "generated_at": datetime.now().isoformat(timespec="seconds"),
        "history_words_7d": hist,
        "memo_blank_lines": blanks,
        "memo_recent_lines": memo_recent,
    }
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, indent=1)
    print(f"[ok] words={len(hist)} blanks={len(blanks)} -> {OUT}")

if __name__ == "__main__":
    main()
