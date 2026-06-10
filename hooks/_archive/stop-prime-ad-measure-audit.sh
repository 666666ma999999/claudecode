#!/bin/bash
# Stop hook: AI 応答末尾を監査し、施策言及があるのに必須トークン未提示なら block
# 2026-05-19 新設 / 2026-05-19 v2 改修 (4 点: 枝番正規表現 + 投入動詞 AND + status:no_target + artifact 期限強化)
#
# 動作:
#  1. Stop event の JSON 入力から transcript_path を取得
#  2. transcript JSONL の末尾 assistant turn の出力テキストを抽出
#  3. 施策言及 = M番号 (枝番含む) + 50字以内に投入動詞 (投入|除外|提案|実行|展開|GO|配信停止|オフ)
#  4. 検出ヒットあり時、artifact (prime_ad/.cache/drift/M<N>_<today>.ok) と
#     必須トークン [M<N>: 🚨X/⚠️Y/🟢Z/🟡W・突合 <date>] の存在/一致を検証
#  5. artifact が status:no_target なら token 要求スキップ
#  6. artifact reference_date が scripts_export 最新日と一致しなければ stale = block
#  7. 不備があれば {"decision":"block", "reason":"..."} を stdout 出力
#
# 環境変数 PRIME_AD_AUDIT=off で一時無効化 (永久無効化禁止)

INPUT=$(cat)

# 一時無効化フラグ
if [ "${PRIME_AD_AUDIT:-on}" = "off" ]; then
    echo "[stop-prime-ad-measure-audit] PRIME_AD_AUDIT=off (skipped)" >&2
    exit 0
fi

# 無限ループ防止
STOP_ACTIVE=$(python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('stop_hook_active',False))" <<<"$INPUT" 2>/dev/null)
if [ "$STOP_ACTIVE" = "True" ]; then
    exit 0
fi

# cwd が prime_suite 系でなければ no-op
case "$(pwd)" in
    */prime_suite*|*/prime_ad*) ;;
    *) exit 0 ;;
esac

TRANSCRIPT=$(python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('transcript_path',''))" <<<"$INPUT" 2>/dev/null)
[ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ] && exit 0

# 最後の assistant turn のテキストを抽出 (+ 施策言及検出を Python に統合)
PWD_PATH="$(pwd)"
export HOOK_TRANSCRIPT="$TRANSCRIPT"
export HOOK_PWD="$PWD_PATH"

DETECTION_JSON=$(python3 <<'PYEOF'
import json
import os
import re
import sys
from pathlib import Path

transcript = os.environ.get("HOOK_TRANSCRIPT", "")
pwd = os.environ.get("HOOK_PWD", "")

# 最後の assistant turn のテキストを抽出
text_parts = []
try:
    with open(transcript) as f:
        lines = f.readlines()
    for ln in reversed(lines):
        try:
            d = json.loads(ln)
        except Exception:
            continue
        if d.get("type") != "assistant":
            continue
        msg = d.get("message", {})
        content = msg.get("content", [])
        if isinstance(content, list):
            for c in content:
                if isinstance(c, dict) and c.get("type") == "text":
                    text_parts.append(c.get("text", ""))
        elif isinstance(content, str):
            text_parts.append(content)
        if text_parts:
            break
except Exception:
    pass

last_assistant = "\n".join(text_parts)
if not last_assistant:
    print(json.dumps({"need_audit": []}))
    sys.exit(0)

# 改修 1: 枝番正規表現 \bM\d+(-\d+[a-z]?)?\b
# 改修 2: 投入動詞 AND (M番号の前後 50 字以内に動詞があるか)
ACTION_VERBS_RE = re.compile(r"投入|除外|提案|実行|展開|配信停止|オフ|\bGO\b")
M_RE = re.compile(r"\bM\d+(?:-\d+[a-z]?)?\b")

mentioned = set()
for m in M_RE.finditer(last_assistant):
    mid = m.group(0)
    start = max(0, m.start() - 50)
    end = min(len(last_assistant), m.end() + 50)
    context = last_assistant[start:end]
    if ACTION_VERBS_RE.search(context):
        mentioned.add(mid)

# tasks/m<N>-*.md パス言及も対象 (パス自体は強いシグナル・動詞不要)
PATH_RE = re.compile(r"tasks/m(\d+(?:-\d+[a-z]?)?)[^\s]*\.md")
for m in PATH_RE.finditer(last_assistant):
    mentioned.add(f"M{m.group(1)}")

# yaml から enabled な施策のみ抽出
yaml_path = Path(pwd) / "prime_ad" / "config" / "measures.yaml"
enabled = set()
if yaml_path.exists():
    try:
        import yaml as yamllib
        cfg = yamllib.safe_load(yaml_path.read_text()) or {}
        for m, info in (cfg.get("measures") or {}).items():
            if info.get("enabled"):
                enabled.add(m)
    except ImportError:
        # 文字列解析フォールバック
        src = yaml_path.read_text()
        blocks = re.findall(r"^  (M\d+(?:-\d+[a-z]?)?):\s*\n((?:    .+\n)+)", src, re.MULTILINE)
        for mid, body in blocks:
            if re.search(r"^    enabled:\s*true\s*$", body, re.MULTILINE):
                enabled.add(mid)

need_audit = sorted(mentioned & enabled)
print(json.dumps({"need_audit": need_audit, "last_assistant": last_assistant}))
PYEOF
)

NEED_AUDIT=$(echo "$DETECTION_JSON" | python3 -c "import json,sys; print(' '.join(json.loads(sys.stdin.read())['need_audit']))" 2>/dev/null)
[ -z "$NEED_AUDIT" ] && exit 0

LAST_ASSISTANT=$(echo "$DETECTION_JSON" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('last_assistant',''))" 2>/dev/null)

# scripts_export の最新日 (artifact は「最新データ日」基準で命名・突合される)
# 注意: 「今日」ではなく scripts_export 最新日を使う。
#       Ads Script は 9:00 取得なので、朝イチは前日が最新。
#       artifact は drift_check が scripts_export 最新日で命名するため、ここも一致させる。
SCRIPTS_LATEST=$(ls -1 "$PWD_PATH/prime_ad/data/raw/google_ads/scripts_export/" 2>/dev/null | grep -E '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' | sort | tail -1)

ISSUES=""
for m in $NEED_AUDIT; do
    ARTIFACT="$PWD_PATH/prime_ad/.cache/drift/${m}_${SCRIPTS_LATEST}.ok"
    if [ ! -f "$ARTIFACT" ]; then
        ISSUES="${ISSUES}\n- ${m}: 最新 scripts_export (${SCRIPTS_LATEST}) の突合 artifact なし (期待: $ARTIFACT)"
        continue
    fi

    # 改修 3: status:no_target なら token 要求スキップ (task.md 不在施策の明示的扱い)
    # 改修 4: artifact reference_date が scripts_export 最新日と一致しなければ stale
    ARTIFACT_INFO=$(python3 -c "
import json
with open('$ARTIFACT') as f: d=json.load(f)
sd=d.get('score_dist',{})
def cnt(k): return sum(v for kk,v in sd.items() if k in kk)
print(d.get('status',''))
print(d.get('reference_date',''))
print(f\"{cnt('🚨')}/{cnt('⚠️')}/{cnt('🟢')}/{cnt('🟡')}\")
" 2>/dev/null)
    STATUS=$(echo "$ARTIFACT_INFO" | sed -n '1p')
    REF_DATE=$(echo "$ARTIFACT_INFO" | sed -n '2p')
    DIST=$(echo "$ARTIFACT_INFO" | sed -n '3p')

    if [ "$STATUS" = "no_target" ]; then
        # task.md 不在で投入候補抽出不能の状態を明示・token 要求スキップ
        continue
    fi

    if [ -n "$SCRIPTS_LATEST" ] && [ -n "$REF_DATE" ] && [ "$REF_DATE" != "$SCRIPTS_LATEST" ]; then
        ISSUES="${ISSUES}\n- ${m}: artifact reference_date=$REF_DATE は最新 scripts_export ($SCRIPTS_LATEST) と不一致 (古いデータで誤 PASS の危険)"
        continue
    fi

    # トークン提示確認
    if ! echo "$LAST_ASSISTANT" | grep -qE "\[${m}:.*突合"; then
        ISSUES="${ISSUES}\n- ${m}: 必須トークン未提示 (期待: [${m}: 🚨X/⚠️Y/🟢Z/🟡W・突合 ...])"
        continue
    fi

    if [ -n "$DIST" ]; then
        OUT_DIST=$(echo "$LAST_ASSISTANT" | grep -oE "\[${m}: 🚨[0-9]+/⚠️[0-9]+/🟢[0-9]+/🟡[0-9]+" | head -1 | sed -E "s|.*🚨([0-9]+)/⚠️([0-9]+)/🟢([0-9]+)/🟡([0-9]+).*|\1/\2/\3/\4|")
        if [ -n "$OUT_DIST" ] && [ "$DIST" != "$OUT_DIST" ]; then
            ISSUES="${ISSUES}\n- ${m}: トークン数値が artifact と不一致 (artifact: $DIST / 出力: $OUT_DIST)"
        fi
        DANGER=$(echo "$DIST" | cut -d/ -f1)
        if [ "${DANGER:-0}" -gt 0 ]; then
            if ! echo "$LAST_ASSISTANT" | grep -qE "(🚨|DANGER).*除外|除外.*(🚨|DANGER)|投入対象外"; then
                ISSUES="${ISSUES}\n- ${m}: 🚨 ${DANGER} 件あるが除外宣言文なし"
            fi
        fi
    fi
done

if [ -n "$ISSUES" ]; then
    REASON="prime_ad 施策言及を検出しましたが現運用突合が不完全です。以下を修正してください:$(echo -e "$ISSUES")\n\n対応: python3 -m prime_ad.scripts.sheet_sync.drift_check --all を実行し、artifact が更新されたことを確認した上で、応答末尾に必須トークン形式で結果を提示してください:\n  [M1: 🚨5/⚠️1/🟢22/🟡18・突合 2026-05-19 18:45]\n  ※ 🚨 X件あり: 投入対象から除外しました\n    - 「KW」(CV X.X件/月)"
    python3 -c "
import json
print(json.dumps({'decision':'block','reason':\"\"\"$REASON\"\"\"}, ensure_ascii=False))
"
    exit 0
fi

exit 0
