#!/bin/bash
# SessionStart hook: ~/.claude（グローバル環境 repo）の commit 忘れ・push 忘れを次セッション冒頭で可視化する。
#
# 背景: rules/10「~/.claude 変更セッションの同セッション commit+push 義務」(2026-07-12 ユーザー恒久指示) の見張り役。
#       散文ルールは忘れられる（実害: 2026-07-11 に 64 ファイル・29h 滞留・未 push 3 commit を実測）。
# 設計思想: 機械は見張りのみ — **書込・commit・block は一切しない**（「良くないものを自動 commit しない」ユーザー懸念
#           2026-07-12 と、承認カード/wiki ✅ゲートと同じ「判断は文脈の中で」の環境思想に準拠）。
# hook-development-guide 準拠: 警告のみ(block なし=暴発上限不要) / state なし / 追記ログなし / headless でも無害(出力は注入文のみ)。
#
# しきい値: 未コミット 1 件以上 or 未 push 1 commit 以上で注入。既定静音（両方ゼロなら無出力）。

REPO="$HOME/.claude"
[ -d "$REPO/.git" ] || exit 0

cd "$REPO" 2>/dev/null || exit 0

dirty=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
ahead=$(git rev-list --count @{u}..HEAD 2>/dev/null || echo 0)

[ "${dirty:-0}" -eq 0 ] && [ "${ahead:-0}" -eq 0 ] && exit 0

last_ts=$(git log -1 --format=%ct 2>/dev/null || echo 0)
hours=$(( ($(date +%s) - last_ts) / 3600 ))

echo "=== 🧷 ~/.claude 同期見張り (rules/10 同セッション commit+push 義務) ==="
if [ "${dirty:-0}" -gt 0 ]; then
  echo "- 未コミット: ${dirty} 件（最終 commit から ${hours} 時間）"
fi
if [ "${ahead:-0}" -gt 0 ]; then
  echo "- 未 push: ${ahead} commit（masa-2 に未達）"
fi
echo "- 前セッションの回収漏れの可能性。区切りが付いた変更なら検証→意味単位で commit→push（rules/10）。作業中の中間状態なら現状のままで可"
exit 0
