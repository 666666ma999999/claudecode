#!/bin/bash
# Stop hook: 完了報告の「残バックログ不可視」を機械保証する（C2 裁定 2026-07-11・skills-audit §7 candidate-2 の hook 化）。
#
# 問題: 「完了/一区切り/残り○○のみ」の報告に残バックログが載らないと、focus mode では
#       未完の作業が画面から消え、同一教訓の翌日再発を招く（miner 所見: 記録だけでは運用されない）。
# 契約: 完了系ワードを含む最終メッセージは、①今回完了 ②親スコープ内の位置 ③残バックログ全件（なし も明記）
#       ④次の選択肢 のうち、少なくとも③（残の明示）を含むこと。欠けたら 1 回だけ block して追記を求める。
#
# 設計は hook-development-guide 準拠:
#  - state は session_id + message-hash 複合キー（stop-evidence-footer.sh と同型・stop_hook_active 非依存）
#  - 完了語の検知は fenced code block / 引用行を除外（naive grep 禁止）
#  - 自己制限: 1 メッセージ 1 回 + SESSION_CAP 4・state 書込不能時は fail-open
#  - 追記ログなし（state は session 単位 txt のみ・data-retention の ephemeral 対象）

# headless 定期実行(vault-prompt-runner)では無効: Stop block は claude -p の出力を分断し本文を消す
[ -n "$VAULT_PROMPT_RUNNER" ] && exit 0

INPUT=$(cat)
export HOOK_INPUT="$INPUT"

python3 -I <<'PYEOF'
import json, os, re, sys, hashlib

def BLOCK(reason):
    print(json.dumps({"decision": "block", "reason": reason}))
    sys.exit(0)

try:
    data = json.loads(os.environ.get("HOOK_INPUT", "{}"))
except json.JSONDecodeError:
    sys.exit(0)

session = str(data.get("session_id", "")) or "nosid"
tpath = data.get("transcript_path", "")
if not tpath or not os.path.isfile(tpath):
    sys.exit(0)  # fail-open

# --- 最終 assistant テキスト抽出（stop-evidence-footer.sh と同型） ---
last_text = ""
try:
    with open(tpath, encoding="utf-8") as f:
        lines = f.readlines()
    for line in reversed(lines):
        line = line.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except json.JSONDecodeError:
            continue
        if obj.get("type") != "assistant":
            continue
        c = obj.get("message", {}).get("content", "")
        if isinstance(c, str):
            txt = c
        elif isinstance(c, list):
            txt = "\n".join(b.get("text", "") for b in c if isinstance(b, dict) and b.get("type") == "text")
        else:
            txt = ""
        if txt.strip():
            last_text = txt
            break
except OSError:
    sys.exit(0)

if not last_text.strip():
    sys.exit(0)

# 短文（挨拶・相槌等）は対象外
if len(re.sub(r"[\s#>*\-`|]", "", last_text)) < 200:
    sys.exit(0)

# --- 構造考慮: fence 内・引用行を検知対象から除外（guide ②） ---
detect_lines, in_fence = [], False
for ln in last_text.splitlines():
    if re.match(r"\s{0,3}(```|~~~)", ln):
        in_fence = not in_fence
        continue
    if in_fence:
        continue
    if re.match(r"\s{0,3}>", ln):   # 引用（過去文の再掲・例示）は除外
        continue
    detect_lines.append(ln)
detect = "\n".join(detect_lines)

# --- 完了系クレームの検知（狭めに・誤検知回避） ---
COMPLETION = [
    r"(?:作業|実装|対応|タスク|移行|修理|適用|処理|全件|すべて|全て)[^\n。]{0,8}完了(?:しました|です|しています)",
    r"完遂(?:しました|です)",
    r"(?:これで|以上で)[^\n。]{0,15}(?:完了|完成|終わり|締ま)",
    r"一区切り(?:です|つきました|にします)",
    r"残り(?:は|も)?[^\n。]{0,20}(?:のみ|だけ)(?:です|になりました)",
    r"すべて(?:完結|終了)しました",
]
claims = any(re.search(p, detect) for p in COMPLETION)
if not claims:
    sys.exit(0)

# --- 残バックログの明示があるか（「なし」の明記も可） ---
BACKLOG = [
    r"残バックログ", r"残タスク", r"残件", r"積み残し", r"やり残し",
    r"残り(?:の)?(?:作業|項目|課題|タスク)",
    r"残(?:り|件|タスク)?(?:は|=|:|：)?\s*(?:なし|ゼロ|ありません|0\s*件)",
    r"✅\s*待ち", r"未完(?:了)?(?:は|:|：)", r"(?:次|ネクスト)(?:の)?(?:選択肢|アクション|一手)",
    r"フォローアップ", r"持ち越し",
]
if any(re.search(p, detect) for p in BACKLOG):
    sys.exit(0)  # 契約充足

# --- 自己制限（message-once + session cap・fail-open） ---
STATE_DIR = os.path.expanduser("~/.claude/state/backlog-guard")
mhash = hashlib.sha1(last_text.encode("utf-8")).hexdigest()[:16]
SESSION_CAP = 4
try:
    os.makedirs(STATE_DIR, exist_ok=True)
    fp = os.path.join(STATE_DIR, session + ".txt")
    seen = []
    if os.path.isfile(fp):
        seen = [l.strip() for l in open(fp, encoding="utf-8") if l.strip()]
    if mhash in seen or len(seen) >= SESSION_CAP:
        sys.exit(0)
    with open(fp, "a", encoding="utf-8") as f:
        f.write(mhash + "\n")
except OSError:
    sys.exit(0)  # fail-open

BLOCK(
    "STOP BLOCKED: 完了報告に残バックログの明示がありません。\n"
    "完了/一区切りを宣言する最終メッセージには次を含めてください（focus mode では書かれなかった未完作業が消えます）:\n"
    "  ①今回完了したこと ②親スコープ内の位置 ③残バックログ全件（無い場合も「残: なし」と明記） ④次の選択肢\n"
    "※ 回答本文は削らず、そのまま再掲した上で追記すること（回答消失の禁止・mistakes.md 恒久ルール 2026-07-10）。"
)
PYEOF
