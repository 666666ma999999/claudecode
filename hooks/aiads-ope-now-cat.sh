#!/usr/bin/env bash
# SessionStart hook: AIads_ope.md の `## now` セクションを抽出して表示
# 司令塔運用 (option A) — セッション開始時に「今聞きたいこと」を可視化
set -euo pipefail

FILE="$HOME/Documents/Obsidian Vault/AIads_ope.md"

[ -f "$FILE" ] || exit 0

# `## now` から次の `## ` 見出しまでを抽出（次の見出しは含まない）
section=$(awk '
  /^## now/ && !seen { seen=1; in_now=1; print; next }
  in_now && /^## / { in_now=0 }
  in_now { print }
' "$FILE")

# 中身が空（または空白のみ）ならスキップ
if [ -z "$(echo "$section" | tr -d '[:space:]')" ]; then
  exit 0
fi

# 長すぎる場合は最大 60 行で切る（暴発防止）
trimmed=$(echo "$section" | head -60)

cat <<EOF
=== AIads_ope.md ## now（司令塔の今聞きたいこと）===
$trimmed
=================================================
EOF
