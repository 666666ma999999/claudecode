#!/bin/bash
# Stop hook: 「完了/push/反映 済み」等の状態宣言があるのに、同じ最終メッセージ内に
# 観測(コマンド出力・件数・git出力・確認/実測語・grep/wc等の実行痕)が皆無なら停止をブロック。
# = recurring-mistakes `obs-before-claim` / mistakes.md `surface-compliance` の act-time 強制版。
# 注入(読む時)でなく、書いた瞬間(Stop)に機械検知するため、注入ルールより実効性が高い。
# 誤検知を最小化: 観測マーカーが1つでもあれば通す。claim が無ければ何もしない。
# stop_hook_active で1停止サイクルにつき最大1回だけブロック(無限ループ防止・絶対壁にしない)。
#
# 導入: 2026-07-02 bunshin「観測なし完了宣言を hook で止める」(注入90%失敗の実測を受けた本物ガード)

# headless 定期実行(vault-prompt-runner)では無効: Stop block は claude -p の出力を分断し本文を消す(2026-07-03 実障害)
[ -n "$VAULT_PROMPT_RUNNER" ] && exit 0

INPUT=$(cat)
export HOOK_INPUT="$INPUT"

python3 -I <<'PYEOF'
import json, os, re, sys

try:
    data = json.loads(os.environ.get("HOOK_INPUT", "{}"))
except json.JSONDecodeError:
    sys.exit(0)

# 無限ループ防止: 一度ブロックして継続→再停止した時は素通し(=最大1回の強いナッジ)
if str(data.get("stop_hook_active", False)).lower() == "true":
    sys.exit(0)

tpath = data.get("transcript_path", "")
if not tpath or not os.path.isfile(tpath):
    sys.exit(0)  # fail-open: 取れない時はブロックしない

# --- 最終 assistant メッセージのテキストを抽出 ---
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
        msg = obj.get("message", {})
        content = msg.get("content", "")
        if isinstance(content, str):
            txt = content
        elif isinstance(content, list):
            txt = "\n".join(
                b.get("text", "") for b in content
                if isinstance(b, dict) and b.get("type") == "text"
            )
        else:
            txt = ""
        if txt.strip():
            last_text = txt
            break
except OSError:
    sys.exit(0)

if not last_text.strip():
    sys.exit(0)

# --- 完了・状態宣言(claim)の検出: 強い done アサーションのみ(高精度) ---
CLAIM_PATTERNS = [
    r"完了しました", r"完了です", r"完了しています", r"実装しました", r"実装完了",
    r"修正しました", r"修正完了", r"反映しました", r"反映済み", r"反映されて(い|)ます",
    r"追加しました", r"削除しました", r"作成しました", r"設定しました", r"更新しました",
    r"対応しました", r"対応済み", r"できました", r"済みです", r"入れました", r"直しました",
    r"push\s*(し|完了|済|done)", r"プッシュしました", r"commit\s*(し|完了|済|done)",
    r"コミットしました", r"コミット完了",
    r"\bdone\b", r"\bcompleted\b", r"\bfixed\b", r"\bimplemented\b",
]
has_claim = any(re.search(p, last_text, re.IGNORECASE) for p in CLAIM_PATTERNS)
if not has_claim:
    sys.exit(0)  # 完了主張が無ければ対象外

# --- 観測(observation)マーカーの検出: 1つでもあれば grounded とみなし通す ---
# = 実際に「読んだ/実行した」痕跡。単なるファイル名の言及(バッククォート1個)は観測に含めない。
OBS_PATTERNS = [
    r"```",                                   # コードフェンス(コマンド出力の提示)
    r"[\w./\-]+\.\w+:\d+",                    # file:line 引用
    r"\d+\s*件", r"\d+\s*行", r"\d+\s*%",     # 出力由来の件数
    r"origin/", r"\s->\s", r"->\s*\w+",       # git 出力
    r"\b[0-9a-f]{7,40}\b",                    # commit hash
    r"\bahead\b", r"\bbehind\b",
    r"確認", r"実測", r"検証", r"実行しました", r"実行済",
    r"\bPASS\b", r"✅", r"\bOK\b",
    r"bash -n", r"\bgrep\b", r"\bwc\b", r"\bcurl\b", r"\bsqlite3\b",
    r"\bpython3\b", r"git (status|log|push|diff|rev-list|ls-files)",
    r"→\s*\d", r"=\s*\d",                     # 検証コマンドの期待値=実測値
]
has_obs = any(re.search(p, last_text) for p in OBS_PATTERNS)
if has_obs:
    sys.exit(0)  # 観測があるので通す(誤検知回避)

# --- claim あり × 観測ゼロ → ブロック ---
reason = (
    '<system-reminder severity="blocking" action-required="observe-before-claim">\n'
    "STOP BLOCKED: 「完了/push/反映 済み」等の状態を宣言していますが、同じ応答内に"
    "観測(コマンド出力・件数・file:line・git出力・確認/実測語)が1つもありません。\n\n"
    "surface-compliance / completion-by-self-report の再発です。次のどちらかで直してから停止してください:\n"
    "  (A) 実際に観測して証拠を添える(例: `git rev-list --left-right --count`、`grep -c`、`ls`、実行ログ)\n"
    "  (B) まだ観測していないなら、宣言を『未確認』へ書き換える\n\n"
    "(このガードは1停止につき最大1回。絶対壁ではなく act-time の強制チェックです)\n"
    "</system-reminder>"
)
print(json.dumps({"decision": "block", "reason": reason}))
sys.exit(0)
PYEOF
