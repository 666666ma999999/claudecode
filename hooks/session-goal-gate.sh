#!/bin/bash
# session-goal-gate.sh — UserPromptSubmit hook（目標照合ゲート）
#
# 目的: 「画面に目標を表示するだけ」の弱い注意書きを、
#       応答冒頭の "必須宣言ゲート" に格上げする。
#       現 worktree の session-goal を毎プロンプト読み、AI に
#       「目標照合: 沿う/逸れる」を先頭で宣言させ、逸れるなら着手前に確認させる。
#
# 経緯: wiki/meta/mistakes.md「anchor-not-consulted」2 回目の恒久対策（2026-06-22）。
#       session-goal を設定済みなのに会話中ずっと未照合で逸脱した再発を、
#       受動的表示ではなく能動的ゲートで止める。
#
# 仕組み: session-goal.sh と同一のパス計算（worktree 単位）で目標ファイルを引く。
#         新しい保存先・新フォーマットは作らない（既存 state を再利用）。

# headless ガード (2026-07-21): vault-prompt-runner の無人 claude -p では返信者がいないため、
# このゲートが応答を乗っ取ると結果 md がパッチ0個になり wiki_ingest_apply が毎日 ABORT する（7/19・7/21 実障害）。
# Stop 系 hook 群と同じ既存マーカーで自粛する。
[ -n "${VAULT_PROMPT_RUNNER:-}" ] && exit 0

input=$(cat)

# UserPromptSubmit hook の stdin JSON から cwd と session_id を取る（無ければ fallback）
_j=$(printf '%s' "$input" | python3 -c "import sys,json;d=json.load(sys.stdin);print(d.get('cwd') or '');print(d.get('session_id') or '')" 2>/dev/null)
cwd=$(printf '%s\n' "$_j" | sed -n '1p')
sid=$(printf '%s\n' "$_j" | sed -n '2p')
[ -z "$cwd" ] && cwd="$PWD"

# session-goal.sh / statusline.sh と同じキー計算（worktree root をサニタイズ・小文字化で casing 差を吸収）
top=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)
dir="${top:-$cwd}"
gdir="$HOME/.claude/state/session-goals"
mkdir -p "$gdir"
key=$(printf '%s' "$dir" | sed 's|[^A-Za-z0-9._-]|-|g; s|^-*||' | tr '[:upper:]' '[:lower:]')

# session(会話)単位: session_id があれば現セッションポインタを毎ターン更新し（writer がこれを読む）、
# 目標は複合キー <key>__<session_id>.txt からのみ読む（別会話の目標を出さないため旧キーへ fallback しない）。
# session_id が無い文脈（headless 等）のみ旧 worktree 単一キーへ degrade。
if [ -n "$sid" ]; then
  printf '%s' "$sid" > "$gdir/.current-$key"
  file="$gdir/${key}__${sid}.txt"
else
  file="$gdir/$key.txt"
fi

goal=""
[ -f "$file" ] && goal=$(head -c 600 "$file" | tr -d '\r' | sed '/^[[:space:]]*$/d' | head -1)

# 鮮度判定: 目標ファイルが前日以前に設定されていれば「古い目標」とみなす。
# 一度セットしたら誰かが /session-goal で上書きするまで永久に凍結する仕様のため、
# 作業が pivot しても古い目標が黙って出続け AI/ユーザー双方を誤誘導する（ターミナル名=今の意図と食い違う）。
# 古い場合は「沿う/逸れる宣言」ではなく「今の作業と合っているか確認」モードに切替える。
# ※ しきい値（前日以前=stale）は statusline.sh の鮮度判定と一致させること（変更時は両方直す・drift 防止）。
#   長期タスクで毎日⚠️が出るのが煩い場合は /session-goal で同じ文言を打ち直せば mtime=当日に更新され消える。
goal_stale=""
goal_setdate=""
if [ -n "$goal" ] && [ -f "$file" ]; then
  goal_setdate=$(stat -f %Sm -t %Y-%m-%d "$file" 2>/dev/null)
  [ -n "$goal_setdate" ] && [ "$goal_setdate" != "$(date +%Y-%m-%d)" ] && goal_stale=1
fi

# 出力判定:
#  - goal あり & 当日設定             → 通常の目標ゲート（沿う/逸れる宣言）
#  - goal あり & 前日以前設定          → 鮮度確認ゲート（今の作業と合っているか先に確認）
#  - goal なし & git リポジトリ内      → 「未設定」リマインド（実プロジェクトなのに目標未設定）
#  - goal なし & 非プロジェクト        → 何も出さない（claude-mem observer 等の裏プロセスからの誤注入ノイズを抑制）
if [ -n "$goal" ] && [ -n "$goal_stale" ]; then
  echo "🎯🚧 目標ゲート（鮮度確認・最優先・無視禁止）"
  echo "今回の目標: $goal  ⚠️（$goal_setdate 設定・古い可能性）"
  echo "■ 応答の最初に1行で確認する → 「この目標は $goal_setdate 設定です。今やっている作業と合っていますか？ ズレていれば /session-goal で更新（または --clear）。」"
  echo "■ ユーザーの今回の依頼がこの目標と明らかに別物なら、古い目標に無理に沿わせず、まず目標の更新可否を確認してから動く。"
  echo "■ 合っているなら、続けて 目標照合: 沿う/逸れる を宣言して進む。"
elif [ -n "$goal" ]; then
  echo "🎯🚧 目標ゲート（最優先・無視禁止）"
  echo "今回の目標: $goal"
  echo "■ 応答の最初の1行で必ず宣言する →  目標照合: [沿う / 逸れる] — <一言理由>"
  echo "■ 「逸れる」なら、作業に着手する前にユーザーへ1行で確認する → 「これは今回の目標から逸れます。寄り道として進めますか／目標を更新しますか？」"
  echo "■ この照合行を書かずに作業を始めるのは規約違反。表示を見て満足せず、必ず宣言してから動く。"
elif [ -n "$top" ]; then
  echo "🎯🚧 目標ゲート（最優先・無視禁止）"
  echo "今回の目標: 【未設定】"
  echo "■ 応答の最初に「今回の目標が未設定です。決めますか？（/session-goal）」と確認するか、依頼から目標を1つ提案する。"
fi
exit 0
