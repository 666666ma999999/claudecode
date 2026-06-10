#!/bin/bash
# UserPromptSubmit hook: ユーザー入力に施策語が含まれていたら "突合先行" reminder を注入
# 2026-05-19 新設 (3 層防御の Layer 1・予防)
#
# 出力すべきは context (stdout に追加コンテキスト) で、ブロックはしない。

INPUT=$(cat)

# cwd が prime_suite 系でなければ no-op
case "$(pwd)" in
    */prime_suite*|*/prime_ad*) ;;
    *) exit 0 ;;
esac

USER_PROMPT=$(python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('prompt',''))" <<<"$INPUT" 2>/dev/null)
[ -z "$USER_PROMPT" ] && exit 0

# 施策言及検出 (M\d+ OR 「施策」「投入」「除外」+ KW/CP/キャンペーン)
if echo "$USER_PROMPT" | grep -qE "\bM[0-9]+\b|tasks/m[0-9]+|投入リスト|施策.*(立案|提案|出して|修正)"; then
    cat <<EOF
【⚠️ prime_ad 施策言及検出】
施策の投入候補・推奨アクションを出す前に必ず:
  1. python3 prime_ad/scripts/sync_sheet.py を実行 (該当 M の artifact 生成)
  2. 応答末尾に必須トークン形式で突合結果を提示:
     [M<N>: 🚨X/⚠️Y/🟢Z/🟡W・突合 <date>]
     ※ 🚨>0 なら除外宣言文も必須

historical aggregate (4M / 6M 累積) 単独での投入候補化は禁止 (execution-conventions.md §9 / prime-ad-drift-gate / stop-prime-ad-measure-audit)。
EOF
fi

exit 0
