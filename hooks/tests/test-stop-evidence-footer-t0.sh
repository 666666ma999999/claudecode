#!/bin/bash
# stop-evidence-footer.sh Tier 0(hook再開ターンの回答消失ガード)の再現テスト。
# 事故実物: 2026-07-10 rohan — stop-dup-guard誤検知ブロック後の継続ターンが「誤検知です」1行になり
#           focus mode で回答本文が消失(mistakes.md append-only-stophook-x-focusmode-erases-answer)。
# 期待: (1)block (2)無出力=自己制限 (3)(4)(5)(6)無出力 (7)block=セッション独立
set -u
H=~/.claude/hooks/stop-evidence-footer.sh
D=$(mktemp -d)
trap 'rm -rf "$D"; rm -f ~/.claude/state/evidence-footer/test-t0-*.txt' EXIT
rm -f ~/.claude/state/evidence-footer/test-t0-*.txt 2>/dev/null

python3 - "$D" <<'PY'
import json, os, sys
d = sys.argv[1]
long_ans = "## ✅ 結論\n全サイト完了ではありません。未登録18件が残っています。" + ("はやとも8件・花凛4件・LoveMeDo3件・JUNO3件。ツールは200OKで使えます。シート4563行を全走査した実データに基づく集計です。" * 8) + "\n🔍根拠: ファクト[実確認]"
short_cont = "誤検知です（VERSION_HISTORY.md の繰り返し見出しは規定フォーマット通りで二重記載ではありません）。以上です。ご確認ください。"
good_cont = "## ✅ 結論 / 決めること\n推奨: 未登録18件を登録することを推奨します。選択肢: 1) 登録する 2) 先にコミット。どうしますか\n" + long_ans
def u(t): return {"type":"user","message":{"role":"user","content":[{"type":"text","text":t}]}}
def a(t): return {"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":t}]}}
def w(name, objs):
    with open(os.path.join(d,name),"w") as f:
        for o in objs: f.write(json.dumps(o,ensure_ascii=False)+"\n")
hookblk = u('<system-reminder severity="blocking" action-required="dedup-single-source">STOP BLOCKED: 二重記載</system-reminder>')
w("t_incident.jsonl", [u("全サイトの教師データは全て登録してますか？"), a(long_ans), hookblk, a(short_cont)])
w("t_good.jsonl",     [u("全サイトの教師データは全て登録してますか？"), a(long_ans), hookblk, a(good_cont)])
w("t_shortprev.jsonl",[u("質問です"), a("はい、そうです。"), hookblk, a(short_cont)])
PY

run() { echo "{\"session_id\":\"$1\",\"stop_hook_active\":$2,\"transcript_path\":\"$D/$3\"}" | bash "$H"; }
echo "== (1) 事故再現(継続・直前長文・最終1行) → block期待 =="
run test-t0-a true t_incident.jsonl; echo "exit=$?"
echo "== (2) 同一入力2回目 → 無出力期待(自己制限) =="
run test-t0-a true t_incident.jsonl; echo "exit=$?"
echo "== (3) stop_hook_active=false → 無出力期待 =="
run test-t0-c false t_incident.jsonl; echo "exit=$?"
echo "== (4) 継続だが結論付き長文 → 無出力期待 =="
run test-t0-d true t_good.jsonl; echo "exit=$?"
echo "== (5) 直前も短文 → 無出力期待 =="
run test-t0-e true t_shortprev.jsonl; echo "exit=$?"
echo "== (6) headless → 無出力 exit=0 期待 =="
echo "{\"session_id\":\"test-t0-f\",\"stop_hook_active\":true,\"transcript_path\":\"$D/t_incident.jsonl\"}" | VAULT_PROMPT_RUNNER=1 bash "$H"; echo "exit=$?"
echo "== (7) 別session_id → 改めてblock期待(state独立) =="
run test-t0-b true t_incident.jsonl | head -c 80; echo; echo "exit=$?"
