#!/usr/bin/env bash
# project-history.sh — プロジェクトの「ざっくり過去作業サマリー」を git 履歴から出す
# usage: project-history.sh [repo_path]   (省略時は今いるフォルダ)
# 出力: 期間 / 日別の作業量 / 作業の種類の集計  ← 大まかな全体像
# 注: set -e / pipefail は使わない（`... | head` の SIGPIPE で途中終了するため）

target="${1:-$PWD}"
cd "$target" 2>/dev/null || { echo "❌ パスが見つかりません: $target"; exit 1; }
root="$(git rev-parse --show-toplevel 2>/dev/null)"
if [ -z "$root" ]; then
  echo "❌ ここは git リポジトリではないので履歴を追えません: $target"
  echo "   (git で管理されているプロジェクトのフォルダで実行してください)"
  exit 1
fi
cd "$root"

name="$(basename "$root")"
count="$(git rev-list --count HEAD)"
first="$(git log --format='%ad' --date=format:'%Y-%m-%d' | tail -1)"   # tail は全読みするので SIGPIPE しない
last="$(git log -1 --format='%ad' --date=format:'%Y-%m-%d')"

echo "📊 ${name} の作業履歴"
echo "   期間: ${first} 〜 ${last}  /  全 ${count} コミット"
echo
echo "─── 日別の作業量（古い順・その日の代表作業つき）───"
git log --reverse --date=format:'%Y-%m-%d' --pretty=format:'%ad｜%s' \
| awk -F'｜' '
  { if ($1!=prev){ if(prev!="") printf "  %s : %2d件  例) %s\n", prev, c, ex; prev=$1; c=0; ex=$2 } c++ }
  END { if(prev!="") printf "  %s : %2d件  例) %s\n", prev, c, ex }'
echo
echo "─── 作業の種類（多い順）───"
git log --format='%s' \
| grep -oE '(分析|施策|診断|検証|反証|データ収集|データ取得|取得手順|文書化|パイプライン|自動化|規約|サマリー|修正|引き継ぎ|セキュリティ|PII|Docker|Phase [0-9][AB]?|plan|KPI|根拠|feat|fix|refactor|chore|docs)' \
| sort | uniq -c | sort -rn | head -15 \
| awk '{ c=$1; $1=""; sub(/^[ \t]+/,""); printf "  %-16s %s回\n", $0, c }'
echo
echo "💡 全コミットを時系列で見る:  git log --reverse --pretty=format:'%ad | %s' --date=short"
echo "💡 期間で絞る:               git log --since=2026-05-01 --pretty=format:'%ad | %s' --date=short"
echo "💡 Claude に頼む:            「このプロジェクトの過去の作業をまとめて（5手順にマップして）」"
