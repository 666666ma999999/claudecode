# /search-best-practice

$ARGUMENTS を検索フォーカス (例: 「hooks」「MCP 最新」) として使用。引数なしなら全軸横断検索。

このコマンドは `search-best-practice` スキルを起動します。詳細は `~/.claude/skills/search-best-practice/SKILL.md` 参照。

## 目的

Web 上の Claude Code 運用ベストプラクティスを検索し、現環境との差分分析から適用計画を立てる。

## Phase 1: 現状把握

直近で `/health` 実行済みならその結果を再利用。未実施なら以下を収集:

- `grep "^##" ~/.claude/CLAUDE.md`
- `~/.claude/rules/*.md` ファイル名
- `~/.claude/skills/*/SKILL.md` 一覧
- `~/.claude/settings.json` の hooks / permissions.deny / statusLine
- `.claude/settings.local.json` (存在時)
- `.mcp.json` の mcpServers

## Phase 2: Web 検索 (SubAgent 1 本)

以下 3 軸で横断調査。各施策は `タイトル / 出典URL / 公開日 / 概要3行以内` で返却、合計 15 件以内。6 ヶ月以上前の情報には `[要鮮度確認]` タグ付与。日英両方で検索。

1. **Hook / Skill 運用パターン** (blog / github / X / Anthropic公式)
2. **MCP サーバー新規推奨** (公式リスト + コミュニティ)
3. **Settings / Permissions 最適化** (セキュリティ観点含む)

## Phase 3: 差分分析 + 適用計画

- 現環境と Web 情報の差分を抽出
- 採用候補 3-5 件に絞り、優先度 / 工数 / 効果見積もり
- Material Bank 登録可能な改善は `/capture-improvement` 連携も提案

## 実行頻度

月 1-2 回推奨。Anthropic 大型アップデート時は随時実行。
