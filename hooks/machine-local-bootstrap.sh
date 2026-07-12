#!/bin/bash
# machine-local-bootstrap.sh — git管理外のマシン固有設定を SessionStart で自動生成（冪等）
# ユーザー明示承認: 2026-07-12 AskUserQuestion「起動時hookを承認する」
#
# 背景: ~/.claude は 2台の Mac（ユーザー名 masaaki / masaaki_nagasawa）で git 同期しているが、
#   - settings.local.json（model のマシン固有指定）
#   - data/bookmarks*.jsonl（ユーザー名依存の絶対パス symlink）
# は 2026-07-12 に git 管理から外した（コンフリクト恒久解消）。
# 欠けているマシンではこの hook が起動時に一度だけ生成する。全て存在すれば完全 no-op。
set -u
CLAUDE_DIR="$HOME/.claude"
created=""

# 1) settings.local.json — model のマシン固有指定（優先度: settings.json より上）
if [ ! -f "$CLAUDE_DIR/settings.local.json" ]; then
  case "${USER:-}" in
    masaaki_nagasawa) model="claude-fable-5[1m]" ;;
    *)                model="sonnet" ;;
  esac
  printf '{\n  "model": "%s"\n}\n' "$model" > "$CLAUDE_DIR/settings.local.json"
  created="$created settings.local.json(model=$model)"
fi

# 2) bookmarks.jsonl symlink — リンク先は両マシンとも $HOME/Desktop/biz/influx 配下
if [ ! -e "$CLAUDE_DIR/data/bookmarks.jsonl" ]; then
  ln -sf "$HOME/Desktop/biz/influx/output/bookmarks.jsonl" "$CLAUDE_DIR/data/bookmarks.jsonl"
  created="$created bookmarks.jsonl"
fi

# 3) bookmarks-normalized.jsonl symlink — リンク先がマシンで異なる（autopost 優先 → influx）
if [ ! -e "$CLAUDE_DIR/data/bookmarks-normalized.jsonl" ]; then
  for t in "$HOME/Desktop/biz/autopost/data/writing_style/bookmarks/normalized.jsonl" \
           "$HOME/Desktop/biz/influx/data/writing_style/bookmarks/normalized.jsonl"; do
    if [ -f "$t" ]; then
      ln -sf "$t" "$CLAUDE_DIR/data/bookmarks-normalized.jsonl"
      created="$created bookmarks-normalized.jsonl"
      break
    fi
  done
fi

[ -n "$created" ] && echo "🔧 machine-local-bootstrap: マシン固有設定を自動生成:$created"
exit 0
