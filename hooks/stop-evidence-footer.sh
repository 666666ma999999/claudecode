#!/bin/bash
# Stop hook: 提案/断定を含む最終応答の「可読性(focus mode)」を機械保証する。
# focus mode ではユーザーは“最終テキストメッセージ”だけを見る。よって最終メッセージ単体に
# 結論(=ユーザーが取るアクション/選ぶ選択肢)が載っていなければ「回答消失」に等しい。
#
# 4-Tier:
#  Tier1 回答消失ガード: フッターだけ/本文空の最終メッセージを拒否(L153再発防止・最優先)
#  Tier2 提案 × フッター無し: 決定ブロックを先頭・根拠中段・フッター末尾を1メッセージで(co-location要求)
#  Tier3 提案 × フッター有り × 結論が先頭に無い: 決定ブロックを先頭へ(埋没是正・提案限定=完了報告は巻き込まない)
#  Tier4 断定を含む完了/検証報告 × フッター無し: 従来どおり末尾に🔍根拠フッター(#1/#3/#5 の act-time 強制)
#
# ループ安全は stop_hook_active でなく session_id + message hash の自前状態(state/evidence-footer/<sid>.txt)で担保。
#   理由: stop_hook_active は「どのStop hookか」を区別しない共有フラグ。複数Stop hookが併存する当環境では
#         全免除フラグに使うと、フック誘発の footer-only 再ターン(L153)を素通しして事故を再現する(Codex敵対レビュー指摘)。
# 誤検知回避: 純粋な質問/計画/雑談・短文(<200)には出さない。完了/検証報告に結論構造を強制しない。fail-open。
#
# 改修: 2026-07-05 提案可読性ガード。一次実例 a9bf41de L166「すいません、どこに回答が書いてあるのですか？」。
#   設計=エージェントチーム / 敵対レビュー=Codex(差し戻し・6修正反映)。詳細 docs/response-structure-detail.md。
#   旧実装: 末尾フッター有無だけで block → フッター単独ターンを誘発し focus modeで回答消失。
# 導入元: 2026-07-02 bunshin「#1〜#5 を毎回チェックする仕組み」(fact-claim-proof / 出典要求 / data-source-first)。

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

# --- 最終 assistant テキスト抽出(実績あるローカル型: transcript逆走。last_assistant_message は当環境で実績ゼロ・未採用) ---
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

# ============ 算出 ============
# canonical footer = 行頭「🔍根拠:」。本文中に「根拠フッター」等と“言及”しただけで has_footer 誤検知しないよう、
#   行頭+コロンに限定(Codexコードレビュー指摘)。has_footer と body split を同一 regex で一致させる。
FOOTER_RE = re.compile(r"(?m)^\s{0,3}🔍\s*根拠\s*[:：]")
has_footer = bool(FOOTER_RE.search(last_text))

# body = フッター行以降 と Sources ブロック(見出し行+箇条書きURL行)を除いた“実本文”(footerと同一regexでsplit)
body = FOOTER_RE.split(last_text)[0]
body = re.sub(r"(?im)^\s*sources?\s*[:：].*$", "", body)                 # Sources: 行
body = re.sub(r"(?im)^\s*[-*]\s*\[[^\]]+\]\([^)]*\)\s*$", "", body)      # 箇条書きリンク行
body_compact = re.sub(r"[\s#>*\-`|・>]", "", body)                       # 記号・空白を落とした実文字

# 提案/選択依頼か: 推奨/提案などの提案語、または明示的な選択依頼(選んでください/どれにしますか/A案…)
#   ※ bold 箇条書き数は is_proposal に使わない(完了報告の「- **…**」で誤検知するため)
PROPOSE = [r"提案(?:し|です|します)", r"施策", r"すべきです", r"べきだ",
           r"推奨(?:し|します|です|は|[:：])", r"おすすめ(?:し|です)",
           r"した方が(?:良|よ)い", r"導入し(?:ましょう|ては)"]
# offers_choice = ユーザーに明示的に「選べ/決めろ」と求めている提案のみ。
#   bare「X案」では判定しない: 過去形の言及(「A案を採用した」等)を拾うと footer付き完了報告を誤ブロックするため(Codex/validator指摘)。
CHOICE_REQUEST = [r"選んでください", r"選択してください", r"決めてください", r"選びますか",
                  r"どれ(?:に|で)?(?:しますか|しましょう)", r"どちらに?(?:しますか|しましょう)",
                  r"いずれに?しますか", r"ど(?:れ|ちら)が(?:よい|いい)(?:ですか)?", r"どうします(?:か|？|\?)"]
has_propose = any(re.search(p, last_text) for p in PROPOSE)
offers_choice = any(re.search(p, last_text) for p in CHOICE_REQUEST)
is_proposal = has_propose or offers_choice
# restructure 対象 = Claude が**推奨を述べ、かつ選択を求めている**応答のみ(has_propose ∧ offers_choice)。
#   推奨のない純粋な選択質問(offers_choice のみ)に「推奨1文」を強制するとstance捏造リスク→対象外(validator新規2)。
#   完了報告の推奨言及(has_propose のみ・選択依頼なし)も対象外(誤ブロック回避)。
is_choice_proposal = has_propose and offers_choice

# 断定(高リスク語のみ・従来資産)
ASSERT = [r"公式(?:は|に|で|上|ドキュメント|仕様)", r"実装(?:は|され|済|しました|されて)",
          r"現状(?:は|では|の)", r"配置(?:は|され|されて)", r"存在(?:し|する|しない|します|しません)",
          r"必ず", r"確実に", r"間違いなく", r"のはず", r"仕様上", r"原理的に"]
has_assert = any(re.search(p, last_text) for p in ASSERT)

# decision_at_top: 「最上部(先頭3非空行)」に決定見出し/推奨マーカー ∧ 実体(選択肢2つ以上 or 推奨文) ∧ 十分な文字。
#   位置=最上部 が肝: 先頭がファクト判定等で推奨が下方にある“埋没”は不合格。空の「## 結論」も実体無しで不合格。
nz_lines = [l for l in last_text.splitlines() if l.strip()]
top = "\n".join(nz_lines[:3])       # マーカー位置は最上部3行
top_win = "\n".join(nz_lines[:10])  # 実体(選択肢/推奨)は決定ブロック近傍(先頭10行)で測る＝デコイ空見出し対策
top_marker = bool(
    re.search(r"(?m)^\s{0,3}#{0,4}\s*(?:✅\s*)?(?:結論|決めること|決定|TL;?DR|BLUF)", top, re.I)
    or re.search(r"(?m)^\s{0,3}(?:#{1,4}\s*)?(?:✅\s*)?\*{0,2}(?:推奨|おすすめ)", top)
)
reco_top = bool(re.search(r"推奨(?:は|[:：]|し|します|です)|おすすめ(?:は|です)|結論(?:は|[:：])", top_win))
# 実体は「推奨文が先頭近傍にある」ことを要求(reco_top)。単なる箇条書き2行では満たさない
#   =先頭に事実bulletを並べ推奨を下方に埋めるデコイを不合格にする(Codex/validator指摘)。
decision_at_top = (top_marker
                   and reco_top
                   and len(re.sub(r"[\s#>*\-`|]", "", top)) >= 6)

# ============ 自前 再ブロック状態(session_id + message hash + tier tag) ============
STATE_DIR = os.path.expanduser("~/.claude/state/evidence-footer")
mhash = hashlib.sha1(last_text.encode("utf-8")).hexdigest()[:16]
SESSION_CAP = 6   # セッション内 再ブロック総数の最終遮断(runaway防止・主保護は message-once)

def already_blocked(tag):
    """(session, message-hash, tier) を既にブロック済みか。未なら記録して False(=今回ブロックしてよい)。"""
    try:
        os.makedirs(STATE_DIR, exist_ok=True)
        fp = os.path.join(STATE_DIR, session + ".txt")
        seen = []
        if os.path.isfile(fp):
            seen = [l.strip() for l in open(fp, encoding="utf-8") if l.strip()]
        key = mhash + ":" + tag
        if key in seen:
            return True          # 同一メッセージ2回目 → ループ安全に通す
        if len(seen) >= SESSION_CAP:
            return True          # セッション上限 → これ以上ブロックしない
        with open(fp, "a", encoding="utf-8") as f:
            f.write(key + "\n")
        return False
    except OSError:
        return True              # 状態を書けない → ブロックしない側に倒す(fail-open)

# ============ Tier 1: 回答消失ガード(最優先・トリガー語/短文除外より前・stop_hook_active非依存) ============
# フッターはあるが実本文が実質空 → focus modeでフッターしか見えない事故(L153)。
if has_footer and len(body_compact) < 40 and not decision_at_top:
    if already_blocked("t1"):
        sys.exit(0)
    BLOCK("最終メッセージが根拠フッター(と出典)だけで、結論本文がありません。"
          "focus modeではこれしか表示されず“回答消失”です。"
          "冒頭に『## ✅ 結論 / 決めること』(推奨1文＋選択肢2つ以上)を置き、"
          "本文の後にフッターを付け直して、1メッセージで出し直してください。")

# ============ 誤検知回避(従来資産を温存) ============
if not (has_assert or is_proposal):
    sys.exit(0)   # 断定も提案も無い(質問・計画・雑談)→対象外
if len(last_text) < 200:
    sys.exit(0)   # 短文除外(儀式コスト回避)
# 質問tail除外: ユーザーへ問うだけのターン(AskUserQuestion 直前等)。
#   ただし「埋没した“推奨つき”選択肢提案」(is_choice_proposal ∧ 結論が先頭に無い)は除外しない=restructureさせる(実L145形)。
#   推奨のない純粋な選択質問は is_choice_proposal=False なので除外が効き、誤ブロックしない(validator新規2)。
is_buried_proposal = is_choice_proposal and not decision_at_top
if (not is_buried_proposal) and re.search(
        r"聞きます|質問します|お聞きします|教えてください|選んでください|どれ(?:に|で)?しますか|どちら|いずれ|回答をください|お答えください",
        last_text[-300:]):
    sys.exit(0)

# ============ Tier 2: 推奨つき選択肢提案 × フッター無し(L145初回形) ============
if is_choice_proposal and not has_footer:
    if already_blocked("t2"):
        sys.exit(0)
    BLOCK("提案/選択依頼を含む応答です。focus mode対策として次を1メッセージで:\n"
          "  [冒頭] 決定ブロック=『## ✅ 結論 / 決めること』(推奨1文＋選択肢2つ以上を先頭に)\n"
          "  [中]  根拠/但し書き(--- で区切り、長文は <details> へ)\n"
          "  [末尾] 🔍根拠: ファクト[…] 出典[…] 現運用[…] 二重記載[…]")

# ============ Tier 3: 推奨つき選択肢提案 × フッター有り × 結論が先頭に無い(埋没形) ============
#   推奨つき選択依頼に限定=完了/検証報告(推奨言及のみ・選択依頼なし)には結論構造を強制しない。
if is_choice_proposal and has_footer and not decision_at_top:
    if already_blocked("t3"):
        sys.exit(0)
    BLOCK("フッターはありますが結論が先頭にありません(決定ポイントが埋没)。"
          "冒頭へ『## ✅ 結論 / 決めること』(推奨1文＋選択肢2つ以上)を移し、"
          "根拠は中段、🔍根拠フッターは末尾のままにしてください。")

# ============ Tier 4: 断定を含む完了/検証報告 × フッター無し(原ガード温存) ============
if has_assert and not is_choice_proposal and not has_footer:
    if already_blocked("t4"):
        sys.exit(0)
    BLOCK('<system-reminder severity="blocking" action-required="evidence-footer">\n'
          "STOP BLOCKED: 事実断定を含む応答ですが、末尾に「根拠フッター」がありません。\n"
          "#1 ファクトチェック / #3 出典 / #5 現運用確認 を毎回意識するための必須儀式です。\n\n"
          "応答の末尾に次の1行を付けてから停止してください(各項目を正直に埋める):\n"
          "  🔍根拠: ファクト[実確認/未確認] 出典[file:line or なし] 現運用[参照済/対象外/未確認] 二重記載[チェック済/対象外]\n\n"
          "『未確認』があるなら、断定を弱めるか、確認してから言い直すこと(嘘の実確認を書かない)。\n"
          "</system-reminder>")

sys.exit(0)   # 完全体(結論先頭＋フッター) or 対象外 → 通す
PYEOF
