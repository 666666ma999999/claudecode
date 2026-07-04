#!/usr/bin/env bash
# SubagentStop hook: SubAgent がファイル編集した形跡があれば、完了前に自己検証させる。
# 2026-07-04 配達監査による再設計: 旧版は「main agent へのリマインダー」を stdout+exit 0 で
# 出していたが、SubagentStop の stdout はモデル非注入(debug log 行き)で main への配達経路は
# 存在しない。decision:block の reason は SubAgent 自身に届く(公式仕様)ため、宛先を
# SubAgent 本人に変更し「差分を観測してから完了報告」を1回だけ強制する。
# ループ防止: stop_hook_active=true なら再ブロックしない。

set -euo pipefail

input=$(cat 2>/dev/null || echo "{}")

# ログ記録（監査用）
LOG_DIR="$HOME/.claude/state"
LOG="$LOG_DIR/subagent-stops.log"
mkdir -p "$LOG_DIR" 2>/dev/null || true

ts=$(date -Iseconds 2>/dev/null || date)
# 入力の先頭 300文字だけログ（PII回避）+ トップレベルキー一覧（入力形状の観測用・2026-07-04）
snippet=$(echo "$input" | head -c 300 | tr '\n' ' ')
keys=$(echo "$input" | python3 -c "import sys,json; print(sorted(json.load(sys.stdin).keys()))" 2>/dev/null || echo "?")
echo "[$ts] keys=$keys $snippet" >> "$LOG" 2>/dev/null || true

# ループ防止: 既に本 hook のブロックで継続中なら素通し
ACTIVE=$(echo "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('stop_hook_active', False))" 2>/dev/null || echo "False")

# SubAgent がファイル編集したかは agent_transcript_path (subagent 自身の transcript) で判定。
# 旧版は入力 JSON 全体を grep していたが、入力はメタデータのみでツール名を含まず
# 本番で一度もマッチしていなかった (2026-07-04 実観測 keys=[...agent_transcript_path...])。
# 注意: transcript_path は親セッションの transcript なので使わない (親の編集で誤発火する)。
AGENT_TRANSCRIPT=$(echo "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('agent_transcript_path',''))" 2>/dev/null || echo "")

if [ "$ACTIVE" != "True" ] && [ -n "$AGENT_TRANSCRIPT" ] && [ -f "$AGENT_TRANSCRIPT" ] \
   && grep -qE '"name"[[:space:]]*:[[:space:]]*"(Write|Edit|NotebookEdit)"' "$AGENT_TRANSCRIPT"; then
  python3 - <<'PY'
import json
print(json.dumps({
    "decision": "block",
    "reason": "【SubAgent Verify】あなた(SubAgent)がファイルを編集した形跡があります。完了前に差分を実ファイルで観測し(Read / git diff / 実行確認のいずれか)、その確認結果を最終報告に1行含めてから停止してください(Trust-but-verify)。"
}, ensure_ascii=False))
PY
fi

exit 0
