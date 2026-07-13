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

# 1) settings.local.json — マシン固有の model / outputStyle（優先度: settings.json より上）
#    ファイルが既存でも「キー」単位で冪等に補正する（file存在チェックだけだと空の
#    settings.local.json が既にあるマシンで一生補正されない＝2026-07-13 の詰まり）。
#    masaaki_nagasawa = Fable 機 → model=fable・outputStyle は付けない
#                                   （Fable 本体に Fable5-like を被せると二重がけで品質劣化）
#    その他           = sonnet 機 → model=sonnet・outputStyle=Fable5-like（mimicry で Fable ライクに）
case "${USER:-}" in
  masaaki_nagasawa) want_model="claude-fable-5[1m]"; want_style="" ;;
  *)                want_model="sonnet";             want_style="Fable5-like" ;;
esac
changed=$(LOCAL_FILE="$CLAUDE_DIR/settings.local.json" WANT_MODEL="$want_model" WANT_STYLE="$want_style" /usr/bin/python3 - <<'PY'
import json, os
p = os.environ["LOCAL_FILE"]
want_model = os.environ["WANT_MODEL"]
want_style = os.environ["WANT_STYLE"]  # "" = そのキーを消す
try:
    with open(p) as f:
        d = json.load(f)
    if not isinstance(d, dict):
        d = {}
except Exception:
    d = {}
chg = []
if d.get("model") != want_model:
    d["model"] = want_model; chg.append("model=%s" % want_model)
if want_style:
    if d.get("outputStyle") != want_style:
        d["outputStyle"] = want_style; chg.append("outputStyle=%s" % want_style)
elif "outputStyle" in d:
    del d["outputStyle"]; chg.append("outputStyle=removed")
if chg:
    with open(p, "w") as f:
        json.dump(d, f, indent=2, ensure_ascii=False)
        f.write("\n")
print(",".join(chg))
PY
)
[ -n "$changed" ] && created="$created settings.local.json($changed)"

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
