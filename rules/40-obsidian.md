# Claude × Obsidian 連携仕様（claude-obsidian 方式）

CLAUDE.md「行動原則 §Obsidian」の詳細仕様。2026-04-24 以降の運用ルール。
本ファイルが claude-obsidian 統合の **カタログ + 共通制約**。各コマンド/スキルの引数・出力例・失敗時挙動は対応 SKILL.md が正典。

## 1. 全体像

- **方式**: AgriciDaniel/claude-obsidian の Karpathy LLM Wiki パターン
- **vault パス**: `~/Documents/Obsidian Vault/`
- **構成要素**: 11 skills + 4 slash commands + 2 agents + 4 hooks + 1 MCP server (mcpvault)
- **目的**: vault を Claude Code の第二の脳として運用し、セッション間で文脈・知見を継承する

## 2. Vault 構造（要点）

- `.raw/` — immutable sources（append-only。書き換え禁止）
- `wiki/` — LLM-maintained 知識ベース（concepts/ entities/ sources/ meta/ canvases/ + hot.md / index.md / log.md）
- `_templates/` — Obsidian Templater 雛形
- 既存 142 件の md ノート — 無変更で grandfather 保持

## 3. スラッシュコマンド・自然言語トリガー

| トリガー | 用途 | 詳細 |
|---|---|---|
| `/wiki` | vault セットアップ確認 / 初期 scaffold / 続きから再開 | `skills/wiki/SKILL.md` |
| `/save [name]` | 現在の会話を wiki ノートとして保存 | `skills/save/SKILL.md` |
| `/canvas [op]` | Canvas に画像/テキスト/PDF/ノート追加、zone 分割 | `skills/canvas/SKILL.md` |
| `/autoresearch <topic>` | iterative web research → wiki/ に filing | `skills/autoresearch/SKILL.md` |
| `ingest <file\|url>` | ソース取込 → wiki/ に 8-15 ページ自動分解 | `skills/wiki-ingest/SKILL.md` |
| `lint the wiki` | orphan / dead link / gap 検出 | `skills/wiki-lint/SKILL.md` |
| `update hot cache` | hot.md を最新会話文脈で刷新 | `skills/wiki/SKILL.md` |
| `query the wiki ...` | wiki 内検索 | `skills/wiki-query/SKILL.md` |
| `fold ...` | 重複ノート統合 | `skills/wiki-fold/SKILL.md` |

## 4. Hooks（自動挙動）

`~/.claude/settings.json` に登録済み。**全 hook は `[ -d wiki ] && [ -d .git ]` ガード付き**で vault 外プロジェクトでは no-op。

| Event | Matcher | 挙動 |
|---|---|---|
| SessionStart | startup\|resume | `wiki/hot.md` を自動 cat してコンテキストに注入 |
| PostToolUse | Write\|Edit | vault かつ `.git` 存在時、`wiki/` `.raw/` を auto-commit |
| Stop | (vault 内) | `wiki/` 変更があれば hot.md 更新を勧めるプロンプト注入 |
| PreCompact | * | compact 直前に `wiki/hot.md` を再読み込み（context 喪失対策） |

退避済み旧 hook: `hooks/_deprecated/{obsidian-now-done-guard.sh, obsidian-session-reminder.sh}`（NOW→DONE 廃止に伴い無効化、保持のみ）。

## 5. MCP Server (mcpvault)

- 登録名: `mcpvault` / パッケージ: `@bitbonsai/mcpvault@latest`
- 環境変数: `MCPVAULT_PATH=${HOME}/Documents/Obsidian Vault`
- 設定: `~/.claude/.mcp.json` / 確認: `claude mcp list`

## 6. 不変ルール（禁止・制約）

### 6.1 既存ノート保護
- vault 直下の既存 142 件 md ノートは **無変更**
- `.obsidian/{workspace,community-plugins,core-plugins,types,templates}.json` 変更禁止
- `.obsidian/plugins/` 配下の既存プラグイン変更禁止

### 6.2 NOW→DONE 運用の廃止
- 2026-04-24 以降、NOW→DONE refs/分離 運用は廃止 → セッション保存は `/save` に一本化
- 既存 NOW/DONE エントリは grandfather 扱いで無編集保持

### 6.3 ディレクトリ規律
- `.raw/` は **append-only**（過去ソースを書き換えない）
- `wiki/` は LLM 自動メンテナンス領域（人手編集も可、ただし PostToolUse hook で auto-commit 発生）
- 他プロジェクトでの Write/Edit が vault に誤コミットされないこと（hook の vault 限定 guard が保証）

### 6.4 シンボリックリンク禁止
- `~/.claude/` 配下、vault 配下とも symlink 不使用。スキル更新もコピー方式

## 7. 関連ファイル

- 設計 SSoT: `~/.claude/plan.md`
- 実装記録: `~/.claude/tasks/p-a-claude-obsidian-integration.md`
- vault バックアップ: `~/.claude/state/vault-backup-20260424/`（手動削除まで保持）

## 8. 優先順位

`CLAUDE.md` > 本ルール（`40-obsidian.md`）> 他 rules/ > 各スキル `SKILL.md`。
コマンド使用例・引数詳細・失敗時挙動は SKILL.md が正典。本ルールはカタログと共通制約のみを定義する。
