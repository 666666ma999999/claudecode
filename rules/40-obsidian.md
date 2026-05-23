---
paths:
  - "**/Obsidian Vault/**"
  - "**/wiki/**"
  - "**/.raw/**"
  - "**/refs/**"
  - "**/*.canvas"
  - "**/*.base"
---

# Obsidian 連携ルール（claude-obsidian 方式）

CLAUDE.md「行動原則 §Obsidian」の不変ルール定義。2026-04-24 以降の運用。
詳細仕様（コマンド使用例・vault 構造・スキル一覧・典型ワークフロー）は `~/.claude/skills/wiki/references/obsidian-integration.md` を参照。

## 適用条件

- 対象 vault: `~/Documents/Obsidian Vault/`
- 構成要素: 10 skills (workflow 層) + 5 slash commands + 4 kepano skills (primitive 層) + 2 agents + 6 hooks + 1 MCP server (mcpvault)
- 退避済み (`skills/_dormant/`、30日未使用): `obsidian-bases` / `obsidian-short-note-merge` / `wiki-fold`
- vault 外プロジェクトでは全 hook が no-op（`[ -d wiki ] && [ -d .git ]` または vault path ガードによる）
- **2 系統併用**: claude-obsidian（知識化 → wiki/）+ obsidian-now-done（証跡 → refs/）

## 基本コマンド（カタログ）

| コマンド | 系統 | 書き込み先 | 詳細 |
|---|---|---|---|
| `/wiki` | claude-obsidian | `wiki/` | `skills/wiki/SKILL.md` |
| `/save [name]` | claude-obsidian | `wiki/` | `skills/save/SKILL.md` |
| `/canvas [op]` | claude-obsidian | `wiki/canvases/` | `skills/canvas/SKILL.md` |
| `/autoresearch <topic>` | claude-obsidian | `wiki/` | `skills/autoresearch/SKILL.md` |
| `/done [task]` | obsidian-now-done | `<project>/refs/` + 該当 MD | `skills/obsidian-now-done/SKILL.md` |
| `ingest <file\|url>` | claude-obsidian | `.raw/` → `wiki/` | `skills/wiki-ingest/SKILL.md` |
| `lint the wiki` | claude-obsidian | `wiki/meta/` | `skills/wiki-lint/SKILL.md` |

## 併用方針（トリガー境界）

| ユーザーの言い方 | 起動スキル | 書き込み先 |
|---|---|---|
| `/save decision`・「決定を記録」・「方針確定」 | claude-obsidian (save) | `wiki/meta/decisions.md`（**append-only、single file**） |
| `/wiki` `/save` `/canvas` `/autoresearch` | claude-obsidian | `wiki/{concepts,entities,sources}/` |
| 「これ保存して」（曖昧） | **既定 = claude-obsidian** | `wiki/` |
| 「原文も」「証跡」「refs に」 | (旧 obsidian-now-done、2026-05-23 退避済み) — `<project>/refs/` に直書き | `refs/` |
| 「要約は wiki、原文は refs」 | claude-obsidian + refs/ 直書き | wiki に `ref:` フィールドで相互リンク |

**Note (2026-05-23)**: `obsidian-now-done` skill と関連 hook (`obsidian-now-done-guard.sh`, `obsidian-session-reminder.sh`) は **`_dormant/` `_deprecated/` に退避済み**。NOW→DONE 運用は廃止。

## kepano-obsidian-skills（primitive 層・2026-05-07 導入）

claude-obsidian (workflow 層) が「**何を作るか**」、kepano (primitive 層) が「**どう正しく書くか**」を担当。共通トリガー: 「obsidian-skills を使って」+ skill 別日本語語彙（YAML description 末尾に追記済み）。

| kepano skill | 役割 | 上位 workflow からの扱い |
|---|---|---|
| `obsidian-markdown` | wikilink/embed/callout/properties 構文 | `save` / `wiki-ingest` の構文整形に委譲 |
| `json-canvas` | `.canvas` JSON Spec 1.0 準拠生成 | `canvas` から JSON 生成規則を委譲 |
| `defuddle` | URL → 本文 markdown 抽出（.md URL 不可） | `autoresearch` / `wiki-ingest` の HTML 抽出を置換 |
| `obsidian-cli` | vault CRUD（要 Obsidian 起動） | **管理者用例外ツール**。一般 workflow から自動発火禁止 |

## obsidian-cli ガード（不変）

vault 全域 CRUD 可能なため、不変ルール（既存 142 件無変更 / `.raw` `refs/` append-only）を一発で破る危険がある。以下を厳守:

- **許可される操作**: `wiki/**` 配下の作成・更新、新規 `.base` / `.canvas` ファイル作成
- **禁止される操作**: vault 直下の既存 142 件 md / `.raw/` 既存ファイル / `<project>/refs/` 既存ファイルの **更新・削除**
- **発火条件**: ユーザーが明示的に `obsidian-cli` を指名した場合のみ。`/save` `/canvas` `/autoresearch` `/wiki-ingest` 等の workflow skill からの自動委譲は禁止
- **代替経路**: vault 操作は原則 `wiki-ingest` / `save` / `canvas` 経由が正系

## hooks 仕様（不変・2026-05-23 更新）

`~/.claude/settings.json` に登録済み。**全 hook は vault path prefix guard 付き**で他プロジェクトでは no-op exit 0。

| Event | Matcher | Hook | 挙動 |
|---|---|---|---|
| SessionStart | * | `wiki-dormant-warn.sh` | 過去 7 日 `wiki/meta/decisions.md` `mistakes.md` 追加 0 件で alert |
| SessionStart | * | `vault-sync-sessionstart.sh` | report プロジェクト pull（既存・継続） |
| UserPromptSubmit | * | `wiki-recall-on-prompt.sh` | `wiki/meta/decisions.md` `mistakes.md` 最新 5 件を context 注入 |
| Stop | * | `wiki-auto-capture-on-stop.sh` | 決定/教訓ワード検出 + decisions.md 30 分未更新で警告 (初版 exit 0、Phase 2 audit 後 exit 2 化検討) |
| Stop | * | `stop-obs-refs-index.sh` | `refs/` 配下の `_index.md` を再生成（既存・継続） |
| Stop | * | `vault-sync-stop.sh` | report プロジェクト push（既存・継続） |
| PreCompact | * | (現状実装なし — 40-obsidian.md 旧記述は虚記述だった、Phase E で修正済み) | |

**退避済 hook (2026-05-23)**: `obsidian-now-done-guard.sh` `obsidian-session-reminder.sh` は `_deprecated/` 退避 + active 側 `.disabled-2026-05-23` リネーム。`posttooluse-vault-warning.sh` `posttooluse-claudeenv.sh` `pretooluse-askuserquestion-guard.sh` は実体不在のため settings.json 参照削除済み。

## 不変ルール（禁止）

- vault 直下の既存 md ノート (5/22 Karpathy LLM Wiki layout 移行で約 8 件 root + サブディレクトリ多数) は **無変更**。触らない
- `.obsidian/{workspace,community-plugins,core-plugins,types,templates}.json` は変更禁止
- `.obsidian/plugins/` 配下の既存プラグインは変更禁止
- `.raw/` は **append-only**。過去ソースを書き換えない
- `<project>/refs/` も **append-only**。元プロンプトの編集・削除禁止
- 知識化（wiki/）と証跡（refs/）は別成果物。曖昧語は知識化が既定、明示語（原文/証跡/refs）で証跡側を起動
- 他プロジェクトでの Write/Edit が vault に誤コミットされないこと（hook の guard が保証）
- `~/.claude/` 配下と vault 配下とも symlink 不使用。スキル更新はコピー方式

## 訂正プロトコル（mistaken MD・Phase E 2026-05-23〜）

過去ノートの誤記を訂正する時のルール。append-only 原則との両立。

- **`.raw/` `<project>/refs/` `vault 直下既存 md` は絶対に触らない**（誤記でも append-only）
- **`wiki/` 配下の訂正**: 同ファイルに `## Updates` セクションを作り、`### YYYY-MM-DD correction` で差分追記。**取消線・本文書き換えは禁止**（grep 容易性・diff 追跡性低下）
- **`hot.md` `_index.md` のみ完全上書き可**（キャッシュ性質、毎回最新スナップショット）
- **`wiki/meta/decisions.md` の訂正**: append-only。撤回時は新 entry に `**Supersedes**: [[YYYY-MM-DD-slug]]` と記す（同 md 冒頭テンプレ準拠）
- **`wiki/meta/mistakes.md` の更新**: de-dup 上書き型。同一パターンを 2 回以上踏んだら 1 entry に統合（同 md 冒頭テンプレ準拠）
- **vault 外プロジェクト（`<repo>/tasks/*.md` 等）からの vault 参照**: wikilink `[[Obsidian Vault/wiki/meta/decisions.md#YYYY-MM-DD-slug]]` で読み取り専用参照。本文転記禁止

## Red Flags

- vault 外プロジェクトで `wiki/` `.raw/` への書き込みが発生している
- hook が `[ -d wiki ]` ガードなしで vault 操作している
- 既存 142 ノートに git diff が出ている
- `.raw/` 配下のファイルが書き換えられている（append-only 違反）
- `obsidian-cli` が `/save` `/canvas` `/autoresearch` `/wiki-ingest` などの workflow skill から自動呼び出しされている
- vault 直下既存 142 件 md / `.raw/` 既存ファイル / `refs/` 既存ファイルが `obsidian-cli` 経由で書き換えられている
- `rules/40-obsidian.md` の行数が 200 行を超えている（公式 200 行ガイドライン違反）

## 関連リンク

- 詳細仕様: `~/.claude/skills/wiki/references/obsidian-integration.md`
- 設計 SSoT: `~/.claude/plan.md`
- 実装記録: `~/.claude/tasks/p-a-claude-obsidian-integration.md`
- vault バックアップ: `~/.claude/state/vault-backup-20260424/`

## 優先順位

`CLAUDE.md` > 本ルール（`40-obsidian.md`）> 他 rules/ > 各スキル `SKILL.md` / `references/*.md`。
本ルールは不変ルールとカタログのみ。コマンド使用例・引数詳細・失敗時挙動は SKILL.md と references/ が正典。
