<!--
プロジェクト版 Vault Integration テンプレ (2026-05-24 作成)

使い方: 本ファイルの "## Vault Integration" 以下を各 project の CLAUDE.md にコピーし、
`<...>` プレースホルダーを当 project の値で埋める。

グローバル版 (全 project 共通の 4 ルール) は `~/.claude/docs/claude-workflow-detail.md` §連携 2 セット を参照。
-->

## Vault Integration

本プロジェクトの Claude × Obsidian 連携。グローバル版は `~/.claude/docs/claude-workflow-detail.md` §連携 2 セット 参照。本セクションは **当 project 固有の投影**。

**プロジェクト MOC**: `vault/02_Ai/<group>/<project>_ope.md` (任意)

### 1. 過去の読み込み (Recall)
- グローバル: recall hook が `wiki/meta/{decisions,mistakes}.md` 最新 5 件を毎 prompt 注入 (自動)
- 当 project 固有素材: `<vault path 例: vault/wiki/x-article-stock.md / vault/.raw/material-bank-*.jsonl>`
- 自動転送 queue (任意): `<script名 が vault からどこに何を流すか>`

### 2. 書き込み (Capture)
- **判断記録**: `/save decision` → `vault/wiki/meta/decisions.md` (グローバル append-only)
- **教訓 (claude のミスをすべて貯める)**: `/save mistake` → `vault/wiki/meta/mistakes.md` (グローバル de-dup)
- **project vs taskMD 境界**:
  - 実行追跡 → `<project>/tasks/*.md` (repo SSoT、vault には書かない)
  - 設計判断 (戦略レベル) → `<project>/plan.md` (repo SSoT)
  - 当 project 独自記録 (任意) → `<vault path 例: x-article-stock.md / impl-notes.md>`

### 3. 上書き (Overwrite)
- **mistaken MD は de-dup** で claude のミスをすべて貯める (グローバル準拠、`wiki/meta/mistakes.md`)
- **vault のサマリー** (`wiki/hot.md` `wiki/_index.md`) は完全上書き可 (キャッシュ性質)
- **当 project 独自の append-only**: `<例: output/drafts/art_NNN_*.md, .raw/<source>/>` (過去無変更)
- **当 project 独自の上書き可**: `<例: x-article-stock.md の state=posted 移行で entry remove>`

### 4. Ingest (外部情報を vault に取り込み・更新)
- グローバル自動取得を活用 (ニュース `collect_news.py` / bookmarks `fetch-bookmarks` → `.raw/`)
- 当 project 固有の手動 ingest (任意): `<例: 公式 docs を /autoresearch <topic> で wiki/sources/<topic>.md に保存>`
- 当 project 固有の `.raw/<source>/` サブディレクトリ (任意): `<例: .raw/<project-source>/>`
- 昇格先 (任意): `wiki/sources/<page>.md` (更新は `## Updates` 差分追記、本文書き換え禁止)
- 公式・外部記事の入手手段: `defuddle` (URL → markdown)、`web_search` / `web_fetch`、`mcp__grok-search__web_search`
