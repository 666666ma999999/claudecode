#!/bin/bash
# Stop hook: このセッションで編集した .md に「構造的な二重記載」があれば停止をブロック。
# = report-single-source(#15 二重記載排除・SSoT一元化) の act-time 強制版(注入でなく機械検知)。
# 検知するのは高精度な2種のみ: (A) 同一 H2/H3 見出しの重複 (B) 長い複数行ブロックの完全重複。
# 意図的に似た構造を持つ台帳(decisions/mistakes 等)・逐語ログ(INBOX/MEMO)・archive は除外(誤検知回避)。
# stop_hook_active で1停止最大1回。
#
# 導入: 2026-07-02 bunshin「#15 二重記載を必ず止める」(ユーザー高ストレス・注入では防げない実測)

# headless 定期実行(vault-prompt-runner)では無効: Stop block は claude -p の出力を分断し本文を消す(2026-07-03 実障害)
[ -n "$VAULT_PROMPT_RUNNER" ] && exit 0

INPUT=$(cat)
export HOOK_INPUT="$INPUT"

python3 -I <<'PYEOF'
import json, os, re, sys
from collections import Counter

try:
    data = json.loads(os.environ.get("HOOK_INPUT", "{}"))
except json.JSONDecodeError:
    sys.exit(0)

if str(data.get("stop_hook_active", False)).lower() == "true":
    sys.exit(0)

session = str(data.get("session_id", ""))
hist = os.path.expanduser("~/.claude/state/edit-history.jsonl")
if not os.path.isfile(hist):
    sys.exit(0)

# --- このセッションで Write/Edit した .md を収集 ---
md_files = []
seen = set()
try:
    with open(hist, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                o = json.loads(line)
            except json.JSONDecodeError:
                continue
            if session and o.get("session") != session:
                continue
            if o.get("tool") not in ("Write", "Edit", "MultiEdit"):
                continue
            fp = o.get("file", "")
            if not fp.endswith(".md"):
                continue
            if fp not in seen:
                seen.add(fp)
                md_files.append(fp)
except OSError:
    sys.exit(0)

if not md_files:
    sys.exit(0)

# --- 除外: 意図的に似た構造/逐語ログ/台帳/archive ---
EXCLUDE_BASENAMES = {
    "decisions.md", "mistakes.md", "MEMORY.md", "recurring-mistakes.md",
    "hot.md", "_index.md", "CHANGELOG.md", "read-history.md",
}
def excluded(fp):
    b = os.path.basename(fp)
    if b in EXCLUDE_BASENAMES:
        return True
    if b.endswith("_INBOX.md") or b.endswith("_MEMO.md"):
        return True
    if "/archive" in fp or "/.raw/" in fp:
        return True
    # frontmatter マーカー
    try:
        head = open(fp, encoding="utf-8").read(600)
    except OSError:
        return True
    if re.search(r"format:\s*(overwrite|append-only|de-dup)", head) or "append-only" in head:
        return True
    return False

def find_dups(fp):
    """(重複見出し, 重複ブロック) を返す"""
    try:
        text = open(fp, encoding="utf-8").read()
    except OSError:
        return [], []
    lines = text.splitlines()

    # (A) 同一 H2/H3 見出しの重複(生成/自動ゾーン内も含むが高精度)
    #     fenced code block 内の見出し例示(テンプレ雛形等)は誤検知源のため除外(2026-07-05 実測: skill-creator/SKILL.md で5回連続誤発火)
    headings = []
    _in_fence = False
    for ln in lines:
        if ln.strip().startswith("```"):
            _in_fence = not _in_fence
            continue
        if _in_fence:
            continue
        if re.match(r"^#{2,3}\s+\S", ln):
            headings.append(ln.strip())
    hc = Counter(headings)
    dup_head = [h for h, c in hc.items() if c >= 2 and len(h) >= 6]

    # (B) 本文ブロック(見出し行を除いた連続非空行の塊・>=80字)の完全重複
    #     見出しは (A) で扱うため本文比較から除外する。テーブル/コードフェンスは除外。
    dup_block = []
    norm = []
    cur = []
    def flush(buf):
        if not buf:
            return
        joined = "\n".join(buf)
        if len(joined.strip()) >= 60:
            key = re.sub(r"\s+", " ", joined.strip())
            if key.count("|") <= len(buf) and not key.lstrip().startswith("```"):
                norm.append(key)
    in_fence = False
    for ln in lines:
        s = ln.strip()
        if s.startswith("```"):
            in_fence = not in_fence
            flush(cur); cur = []
            continue
        if in_fence:
            continue
        if not s or re.match(r"^#{1,6}\s", ln):   # 空行 or 見出しでブロック区切り
            flush(cur); cur = []
        else:
            cur.append(s)
    flush(cur)
    pc = Counter(norm)
    dup_block = [k[:60] for k, c in pc.items() if c >= 2]

    return dup_head, dup_block

hits = []
for fp in md_files:
    if not os.path.isfile(fp) or excluded(fp):
        continue
    dh, db = find_dups(fp)
    if dh or db:
        hits.append((fp, dh, db))

if not hits:
    sys.exit(0)

detail = []
for fp, dh, db in hits[:5]:
    b = os.path.basename(fp)
    if dh:
        detail.append(f"  {b}: 重複見出し {dh[:3]}")
    if db:
        detail.append(f"  {b}: 重複ブロック {db[:2]}")
reason = (
    '<system-reminder severity="blocking" action-required="dedup-single-source">\n'
    "STOP BLOCKED: 今セッションで編集した .md に構造的な二重記載があります(#15 SSoT一元化)。\n\n"
    + "\n".join(detail) + "\n\n"
    "同じ情報を1箇所(正本)に集約し、重複側は削除するか参照(リンク)に置き換えてから停止してください。\n"
    "誤検知(意図的な繰り返し)なら、その旨を1行明記して続行してよい(このガードは1停止最大1回)。\n"
    "</system-reminder>"
)
print(json.dumps({"decision": "block", "reason": reason}))
sys.exit(0)
PYEOF
