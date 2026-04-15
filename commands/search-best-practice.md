# /search-best-practice

$ARGUMENTS を検索フォーカス (例: 「hooks」「MCP 最新」) として使用。引数なしなら全軸横断検索。

このコマンドは **`search-best-practice`** スキルを起動します。**全 Phase (現状把握・Web 検索・差分分析・ユーザー確認と適用) の詳細手順は** `~/.claude/skills/search-best-practice/SKILL.md` を参照してください (複製しない — 常に skill 側が正)。

## 起動後の最初のアクション

1. `~/.claude/skills/search-best-practice/SKILL.md` を Read で読み込む
2. Phase 1 から skill の指示通りに順次実行 (全 Phase を省略しない)
3. $ARGUMENTS の検索フォーカスを Phase 2 SubAgent 指示に反映

## 用途の要約 (1 行)

Web 上の Claude Code 運用ベストプラクティスを検索 → 現環境差分分析 → 採用候補を提示 → ユーザー確認後に適用。
