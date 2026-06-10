#!/usr/bin/env bash
# place-methodology.sh — 現プロジェクトに作業メソドロジー雛形(0層+①〜⑥+メタ層)を配置する
# usage: place-methodology.sh [dest_dir]   省略時: docs/ があれば docs/、なければ ./
set -u

SRC="$HOME/.claude/templates/methodology-5step.md"
if [ ! -f "$SRC" ]; then
  echo "❌ テンプレが見つかりません: $SRC"
  exit 1
fi

dest_dir="${1:-}"
if [ -z "$dest_dir" ]; then
  if [ -d "./docs" ]; then dest_dir="./docs"; else dest_dir="."; fi
fi
mkdir -p "$dest_dir" 2>/dev/null
dest="$dest_dir/methodology-5step.md"

if [ -e "$dest" ]; then
  echo "⚠️ 既に存在するので上書きしません: $dest"
  echo "   置き換えたい場合は手動で削除してから再実行してください。"
  exit 0
fi

cp "$SRC" "$dest"
echo "✅ 配置しました: $dest"
echo
echo "次にやること:"
echo "  - 各ステップの「問い」に、このプロジェクトのデータ・ツールで答えてタスクを埋める"
echo "  - お手本（prime_ad/crm の具体例）: Obsidian で [[prime_suite-methodology-draft]] を開く"
