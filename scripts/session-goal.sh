#!/usr/bin/env bash
# session-goal.sh — 「今回のセッション目標」を set / show / clear する。
# statusline.sh の4行目 (🎯 今回の目標: ...) に表示される。
#
# 保存先: ~/.claude/state/session-goals/<worktree-key>__<session_id>.txt
#   - repo の外に置くので git を汚さない
#   - 単位は「セッション(会話)」(2026-06-23〜)。同じフォルダ(worktree)でも会話ごとに別目標を持てる。
#     → session_id は gate(session-goal-gate.sh)が毎ターン stdin から読み .current-<key> に書く。
#       writer はそれを読んで複合キーにするので statusline/gate と同じ session_id でキーが一致する。
#     → resume / /clear で session_id が変わると「新しい会話」扱い=目標は引き継がない(未設定に戻る)。
#     → ポインタが無い文脈(headless 等)のみ旧 worktree 単一キー <key>.txt へ degrade。
#
# usage:
#   session-goal.sh "目標テキスト"   # 今いる project の目標を設定 (上書き)
#   session-goal.sh                  # 現在の目標を表示
#   session-goal.sh --clear          # 目標を消す (4行目が消える)

_top="$(git rev-parse --show-toplevel 2>/dev/null)"
if [ -n "$_top" ]; then dir="$_top"; else dir="$(pwd -P)"; fi
key=$(printf '%s' "$dir" | sed 's|[^A-Za-z0-9._-]|-|g; s|^-*||' | tr '[:upper:]' '[:lower:]')
gdir="$HOME/.claude/state/session-goals"
mkdir -p "$gdir"
# session(会話)単位の目標にする。現セッションの session_id は gate(session-goal-gate.sh)が
# 毎ターン stdin から読んで $gdir/.current-<key> に書く。それを読んで複合キー化する
# (statusline/gate も同じ stdin session_id を使うので3接点でキーが一致)。
# ポインタが無い文脈(headless 等)のみ旧 worktree 単一キーへ degrade。
sid=""
[ -f "$gdir/.current-$key" ] && sid=$(head -1 "$gdir/.current-$key" | tr -d '\r\n')
if [ -n "$sid" ]; then file="$gdir/${key}__${sid}.txt"; else file="$gdir/$key.txt"; fi

case "${1:-}" in
  "")
    if [ -f "$file" ]; then echo "🎯 今回の目標: $(cat "$file")"; else echo "(目標 未設定)"; fi
    ;;
  --clear)
    rm -f "$file" && echo "🎯 目標をクリアしました ($(basename "$dir"))"
    ;;
  *)
    printf '%s\n' "$1" > "$file"
    echo "🎯 今回の目標を設定 ($(basename "$dir")): $1"
    ;;
esac
