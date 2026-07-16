#!/bin/bash
# SessionStart hook: git 同期見張り（① ~/.claude 環境 repo + ② セッションの project repo）
#
# [① 環境 repo] rules/10「~/.claude 変更セッションの同セッション commit+push 義務」(2026-07-12 ユーザー恒久指示) の見張り役。
#   背景: 散文ルールは忘れられる（実害: 2026-07-11 に 64 ファイル・29h 滞留・未 push 3 commit を実測）。
# [② project repo] 未コミット/未 push を可視化し、/commit-push-pr（lint→個別add→commit→push→PR 一括）への導線を出す。
#   出典: provenance-ledger 検討課題1「/commit-push-pr を hook で活用」（本人指示 2026-07-15・使用0回コマンドの活性化）。
#   ノイズ対策: project 側は tracked 変更＋未 push のみ数える（生成物 png 等で常時散らかる repo での毎セッション発火を防ぐ。
#   untracked を含むのは①環境 repo のみ＝従来挙動維持）。
# 設計思想: 機械は見張りのみ — **書込・commit・block は一切しない**（「良くないものを自動 commit しない」ユーザー懸念
#           2026-07-12 と、承認カード/wiki ✅ゲートと同じ「判断は文脈の中で」の環境思想に準拠）。
# hook-development-guide 準拠: 警告のみ(block なし=暴発上限不要) / state なし / 追記ログなし / headless でも無害(出力は注入文のみ)。
#
# しきい値: 未コミット 1 件以上 or 未 push 1 commit 以上で注入。既定静音（両方ゼロなら無出力）。

# $1=repo $2=untracked を数えるか(1/0) → "dirty ahead hours" を echo（対象外・ドリフトなしは無出力）
drift_lines() {
  local repo="$1" inc_untracked="$2" dirty ahead last_ts hours
  [ -d "$repo/.git" ] || return 0
  if [ "$inc_untracked" = "1" ]; then
    dirty=$(git -C "$repo" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  else
    dirty=$(git -C "$repo" status --porcelain 2>/dev/null | grep -cv '^??')
  fi
  ahead=$(git -C "$repo" rev-list --count '@{u}..HEAD' 2>/dev/null || echo 0)
  [ "${dirty:-0}" -eq 0 ] && [ "${ahead:-0}" -eq 0 ] && return 0
  last_ts=$(git -C "$repo" log -1 --format=%ct 2>/dev/null || echo 0)
  hours=$(( ($(date +%s) - last_ts) / 3600 ))
  echo "${dirty:-0} ${ahead:-0} ${hours}"
}

# --- ① 環境 repo (~/.claude) ---
ENV_REPO="$HOME/.claude"
env_d=$(drift_lines "$ENV_REPO" 1)
if [ -n "$env_d" ]; then
  read -r dirty ahead hours <<< "$env_d"
  echo "=== 🧷 ~/.claude 同期見張り (rules/10 同セッション commit+push 義務) ==="
  [ "$dirty" -gt 0 ] && echo "- 未コミット: ${dirty} 件（最終 commit から ${hours} 時間）"
  [ "$ahead" -gt 0 ] && echo "- 未 push: ${ahead} commit（masa-2 に未達）"
  echo "- 前セッションの回収漏れの可能性。区切りが付いた変更なら検証→意味単位で commit→push（rules/10）。作業中の中間状態なら現状のままで可"
fi

# --- ② project repo（cwd）: /commit-push-pr への導線 ---
PROJ="${CLAUDE_PROJECT_DIR:-$PWD}"
case "$PROJ" in
  "$ENV_REPO"|"$ENV_REPO"/*) PROJ="" ;;                    # 環境 repo は①が担当
  "$HOME/Documents/Obsidian Vault"*) PROJ="" ;;            # vault は obsidian-git/CCSYNC が担当
esac
if [ -n "$PROJ" ]; then
  root=$(git -C "$PROJ" rev-parse --show-toplevel 2>/dev/null)
  proj_d=""
  [ -n "$root" ] && proj_d=$(drift_lines "$root" 0)
  if [ -n "$proj_d" ]; then
    read -r dirty ahead hours <<< "$proj_d"
    echo "=== 🧷 project repo 同期見張り ($(basename "$root")) ==="
    [ "$dirty" -gt 0 ] && echo "- 未コミット(tracked): ${dirty} 件（最終 commit から ${hours} 時間）"
    [ "$ahead" -gt 0 ] && echo "- 未 push: ${ahead} commit"
    echo "- 区切りが付いた変更なら /commit-push-pr で lint→個別add→commit→push→PR まで一括で片付け可（作業中の中間状態なら現状のままで可）"
  fi
fi
exit 0
