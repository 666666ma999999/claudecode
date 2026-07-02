#!/bin/bash
# Stop hook: 事実主張(公式/実装/現状/配置/存在/必ず)や提案(施策/すべき/推奨)を含む応答なのに、
# 末尾に「根拠フッター」(🔍根拠: ファクト.../出典.../現運用...)が無ければ停止をブロック。
# = fact-claim-proof(#1) / 出典要求(#3) / data-source-first(#5) の act-time 強制版。
# 目標ゲート(唯一守られている注入=1行儀式)と同じ「単純・必須・確認可能」な型を検証まで含めて強制する。
# stop_hook_active で1停止最大1回。純粋な質問・計画・雑談には出さない(=誤検知回避)。
#
# 導入: 2026-07-02 bunshin「#1〜#5 を毎回チェックする仕組み」(ユーザー最大ストレスへの本物ガード)

INPUT=$(cat)
export HOOK_INPUT="$INPUT"

python3 -I <<'PYEOF'
import json, os, re, sys

try:
    data = json.loads(os.environ.get("HOOK_INPUT", "{}"))
except json.JSONDecodeError:
    sys.exit(0)

if str(data.get("stop_hook_active", False)).lower() == "true":
    sys.exit(0)

tpath = data.get("transcript_path", "")
if not tpath or not os.path.isfile(tpath):
    sys.exit(0)  # fail-open

# --- 最終 assistant テキスト抽出 ---
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

# --- 既にフッターがあれば通す(最優先・誤検知回避) ---
if re.search(r"🔍\s*根拠|根拠チェック|根拠フッター", last_text):
    sys.exit(0)

# --- トリガー: 事実断定 or 提案 を含むか(#1/#3=断定, #5=提案) ---
# fact-claim-proof が挙げる危険語 + 提案語に限定(全断定でなく高リスク語のみ=誤検知抑制)
ASSERT = [
    r"公式(?:は|に|で|上|ドキュメント|仕様)", r"実装(?:は|され|済|しました|されて)",
    r"現状(?:は|では|の)", r"配置(?:は|され|されて)", r"存在(?:し|する|しない|します|しません)",
    r"必ず", r"確実に", r"間違いなく", r"〜のはず", r"仕様上", r"原理的に",
]
PROPOSE = [
    r"提案(?:し|です|します)", r"施策", r"すべきです", r"べきだ", r"推奨(?:し|します|です)",
    r"おすすめ(?:し|です)", r"した方が(?:良|よ)い", r"導入し(?:ましょう|ては)",
]
has_assert = any(re.search(p, last_text) for p in ASSERT)
has_propose = any(re.search(p, last_text) for p in PROPOSE)
if not (has_assert or has_propose):
    sys.exit(0)  # 断定も提案も無い(質問・計画・雑談)→対象外

# --- 短い応答は対象外(儀式コスト回避・雑談での誤発火防止) ---
if len(last_text) < 200:
    sys.exit(0)

# --- トリガーあり × フッター無し → ブロック ---
reason = (
    '<system-reminder severity="blocking" action-required="evidence-footer">\n'
    "STOP BLOCKED: 事実断定または提案を含む応答ですが、末尾に「根拠フッター」がありません。\n"
    "#1 ファクトチェック / #3 出典 / #5 現運用確認 を毎回意識するための必須儀式です。\n\n"
    "応答の末尾に次の1行を付けてから停止してください(各項目を正直に埋める):\n"
    "  🔍根拠: ファクト[実確認/未確認] 出典[file:line or なし] 現運用[参照済/対象外/未確認] 二重記載[チェック済/対象外]\n\n"
    "『未確認』があるなら、断定・提案を弱めるか、確認してから言い直すこと(嘘の実確認を書かない)。\n"
    "(このガードは1停止につき最大1回・質問/計画/短文には出ません)\n"
    "</system-reminder>"
)
print(json.dumps({"decision": "block", "reason": reason}))
sys.exit(0)
PYEOF
