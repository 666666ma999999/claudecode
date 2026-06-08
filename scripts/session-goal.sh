#!/usr/bin/env bash
# session-goal.sh — 「今回のセッション目標」を set / show / clear する。
# statusline.sh の4行目 (🎯 今回の目標: ...) に表示される。
#
# 保存先: ~/.claude/state/session-goals/<worktree-root をサニタイズ>.txt
#   - repo の外に置くので git を汚さない
#   - project の判定は「作業ツリー (worktree)」単位 (--show-toplevel)。
#     → worktree ごとに別々の目標を持てる。メインリポジトリも 1 つの作業ツリーとして独立。
#     → 同じパスに worktree を作り直せば目標は残る (パスが変われば別目標)。
#     → statusline.sh も同じ基準で読むので必ず一致する。
#
# usage:
#   session-goal.sh "目標テキスト"   # 今いる project の目標を設定 (上書き)
#   session-goal.sh                  # 現在の目標を表示
#   session-goal.sh --clear          # 目標を消す (4行目が消える)

_top="$(git rev-parse --show-toplevel 2>/dev/null)"
if [ -n "$_top" ]; then dir="$_top"; else dir="$(pwd -P)"; fi
key=$(printf '%s' "$dir" | sed 's|[^A-Za-z0-9._-]|-|g; s|^-*||')
gdir="$HOME/.claude/state/session-goals"
file="$gdir/$key.txt"
mkdir -p "$gdir"

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
