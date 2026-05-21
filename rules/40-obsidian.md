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
| `/save` `/wiki` `/canvas` `/autoresearch` | claude-obsidian | `wiki/{concepts,entities,decisions,sources}/` |
| `/done`「タスク完了」「NOW→DONE」 | obsidian-now-done | `<project>/refs/` + 該当 MD `## DONE` |
| 「これ保存して」（曖昧） | **既定 = claude-obsidian** | `wiki/` |
| 「原文も」「証跡」「ログ」「refs に」 | obsidian-now-done | `refs/` |
| 「要約は wiki、原文は refs」 | 両方（順序: refs → wiki） | 両方 + wiki に `ref:` フィールドで相互リンク |

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

## hooks 仕様（不変）

`~/.claude/settings.json` に登録済み。**全 hook は vault 限定 guard 付き**で他プロジェクトでは無作動。

| Event | Matcher | 挙動 | ガード条件 |
|---|---|---|---|
| SessionStart | startup\|resume | `wiki/hot.md` を自動 `cat` | `[ -f wiki/hot.md ]` |
| SessionStart | * | DONE 形式違反を警告（obsidian-now-done） | vault 内 + `## DONE` 含む MD あり |
| PostToolUse | Write\|Edit | `wiki/` `.raw/` を auto-commit | `[ -d wiki ] && [ -d .git ]` |
| PostToolUse | Write\|Edit | DONE エントリの refs/ 分離形式を検証（obsidian-now-done） | vault 内 `*.md` + `## DONE` 含む |
| Stop | * | `hot.md` 更新プロンプトを注入 | vault 内 + `wiki/` 変更あり |
| PreCompact | * | `wiki/hot.md` を再読み込み | vault 内 |

## 不変ルール（禁止）

- vault 直下の既存 142 件 md ノートは **無変更**。触らない
- `.obsidian/{workspace,community-plugins,core-plugins,types,templates}.json` は変更禁止
- `.obsidian/plugins/` 配下の既存プラグインは変更禁止
- `.raw/` は **append-only**。過去ソースを書き換えない
- `<project>/refs/` も **append-only**（obsidian-now-done 系統）。元プロンプトの編集・削除禁止
- 知識化（wiki/）と証跡（refs/）は別成果物。曖昧語は知識化が既定、明示語（原文/証跡/refs）で証跡側を起動
- 他プロジェクトでの Write/Edit が vault に誤コミットされないこと（hook の guard が保証）
- `~/.claude/` 配下と vault 配下とも symlink 不使用。スキル更新はコピー方式

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
