#!/bin/bash
# stop-evidence-footer.sh Tier1b(AskUserQuestion同時呼び出しガード)の再現テスト。
# 事故実物: 2026-07-14 prime_suite — 本文(結論/根拠)を書いた直後、同一ターンでAskUserQuestionを呼ぶと
#           focus modeでツールUIが最終表示を差し替え、直前の本文が画面から消える。
#           Fable5/Codex敵対レビューで裏取り(commit c9ee0588の"質問tail除外"が誤って免除していた経路)。
# フィクスチャ形状の根拠: Validator実データ全数調査(2026-07-14)で、AskUserQuestion tool_useは本文と同一
#           メッセージに同居せず、必ず「本文メッセージ→AskUserQuestion単独メッセージ」の別行構成(98/98)。
#           本テストは初版(同一メッセージ同居を仮定)が非現実的だったための再実装(Validator指摘 Critical#2)。
# 期待: (1)block (2)無出力=自己制限 (3)無出力=AskUserQuestionなし・既存の質問tail除外を温存(回帰)
#       (4)無出力=短文除外 (5)無出力=断定/提案なし (6)無出力=旧ターンのAskUserQuestionは境界を越えて漏れない
#       (7)block=間に別のtool_use(Bashなど)を挟んでも検出できる
set -u
H=~/.claude/hooks/stop-evidence-footer.sh
D=$(mktemp -d)
trap 'rm -rf "$D"; rm -f ~/.claude/state/evidence-footer/test-askuq-*.txt' EXIT
rm -f ~/.claude/state/evidence-footer/test-askuq-*.txt 2>/dev/null

python3 - "$D" <<'PY'
import json, os, sys
d = sys.argv[1]

long_body = "## 問題点\n" + ("既存の実装は現状こうなっており、config.jsonに配置されています。仕様上この構成が必要です。" * 6)
long_body_exempt = long_body + "\nどちらの案がよいか教えてください。"
long_body_footer = long_body + "\n🔍根拠: ファクト[実確認] 出典[なし] 現運用[対象外] 二重記載[対象外]"
short_assert = "現状はまだ確認中です。"          # has_assert=True だが 200字未満
casual = "はい元気です。"                        # has_assert/is_proposal どちらも無し

def u(t):
    return {"type": "user", "message": {"role": "user", "content": [{"type": "text", "text": t}]}}

def a(t):
    return {"type": "assistant", "message": {"role": "assistant", "content": [{"type": "text", "text": t}]}}

def askuq():
    # 実データ実測どおり: text無し・tool_use単独のassistantメッセージ
    return {"type": "assistant", "message": {"role": "assistant", "content": [
        {"type": "tool_use", "id": "toolu_1", "name": "AskUserQuestion", "input": {"questions": []}},
    ]}}

def bash_call():
    return {"type": "assistant", "message": {"role": "assistant", "content": [
        {"type": "tool_use", "id": "toolu_2", "name": "Bash", "input": {"command": "echo hi"}},
    ]}}

def tool_result():
    return {"type": "user", "message": {"role": "user", "content": [
        {"type": "tool_result", "tool_use_id": "toolu_2", "content": [{"type": "text", "text": "hi"}]},
    ]}}

def w(name, objs):
    with open(os.path.join(d, name), "w") as f:
        for o in objs:
            f.write(json.dumps(o, ensure_ascii=False) + "\n")

# (1)(2) 本文 → 別行でAskUserQuestion単独メッセージ(実データ形状)
w("askuq_block.jsonl", [u("状況を教えて"), a(long_body), askuq()])
# (3) AskUserQuestionなし・末尾が質問文言 → 既存の質問tail除外(回帰確認)
w("askuq_exempt_noaskuq.jsonl", [u("状況を教えて"), a(long_body_exempt)])
# (4) 断定はあるが200字未満 + AskUserQuestion
w("askuq_short.jsonl", [u("状況を教えて"), a(short_assert), askuq()])
# (5) 断定/提案なし + AskUserQuestion
w("askuq_casual.jsonl", [u("元気？"), a(casual), askuq()])
# (6) 旧ターンでAskUserQuestion→実ユーザーが回答→新ターンは本文のみ(フッター付き・AskUserQuestionなし)
w("askuq_prior_turn.jsonl", [
    u("状況を教えて"), a("短い前置き。"), askuq(),
    u("わかりました"), a(long_body_footer),
])
# (7) 本文の後、AskUserQuestionを呼ぶ前に別のtool_use(Bash)を挟む
w("askuq_via_bash.jsonl", [u("状況を教えて"), a(long_body), bash_call(), tool_result(), askuq()])
PY

run() { echo "{\"session_id\":\"$1\",\"stop_hook_active\":false,\"transcript_path\":\"$D/$2\"}" | bash "$H"; }

echo "== (1) 本文(断定≥200字)→別メッセージでAskUserQuestion(実データ形状) → block期待 =="
run test-askuq-a askuq_block.jsonl; echo "exit=$?"

echo "== (2) 同一入力2回目 → 無出力期待(自己制限) =="
run test-askuq-a askuq_block.jsonl; echo "exit=$?"

echo "== (3) AskUserQuestionなし・末尾が質問文言 → 無出力期待(既存の質問tail除外を温存・回帰確認) =="
run test-askuq-b askuq_exempt_noaskuq.jsonl; echo "exit=$?"

echo "== (4) 断定はあるが200字未満+AskUserQuestion → 無出力期待(短文除外) =="
run test-askuq-c askuq_short.jsonl; echo "exit=$?"

echo "== (5) 断定/提案なし+AskUserQuestion → 無出力期待(対象外) =="
run test-askuq-d askuq_casual.jsonl; echo "exit=$?"

echo "== (6) AskUserQuestionは旧ターンのみ・新ターンは本文のみ(フッター付) → 無出力期待(ターン境界を越えない) =="
run test-askuq-e askuq_prior_turn.jsonl; echo "exit=$?"

echo "== (7) 本文→Bash呼び出し→AskUserQuestion(間に別ツール) → block期待(検出漏れしない) =="
run test-askuq-f askuq_via_bash.jsonl; echo "exit=$?"
