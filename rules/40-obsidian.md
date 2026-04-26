# Obsidian 連携ルール（claude-obsidian 方式）

CLAUDE.md「行動原則 §Obsidian」の不変ルール定義。2026-04-24 以降の運用。
詳細仕様（コマンド使用例・vault 構造・スキル一覧・典型ワークフロー）は `~/.claude/skills/wiki/references/obsidian-integration.md` を参照。

## 適用条件

- 対象 vault: `~/Documents/Obsidian Vault/`
- 構成要素: 12 skills + 5 slash commands + 2 agents + 6 hooks + 1 MCP server (mcpvault)
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

## hooks 仕様（不変）

`~/.claude/settings.json` に登録済み。**全 hook は vault 限定 guard 付き**で他プロジェクトでは無作動。

| Event | Matcher | 挙動 | ガード条件 |
|---|---|---|---|
| SessionStart | startup\|resume | `wiki/hot.md` を自動 `cat` | `[ -f wiki/hot.md ]` |
| PostToolUse | Write\|Edit | `wiki/` `.raw/` を auto-commit | `[ -d wiki ] && [ -d .git ]` |
| Stop | * | `hot.md` 更新プロンプトを注入 | vault 内 + `wiki/` 変更あり |
| PreCompact | * | `wiki/hot.md` を再読み込み | vault 内 |

退避済み旧 hook: `~/.claude/hooks/_deprecated/{obsidian-now-done-guard.sh, obsidian-session-reminder.sh}`。物理削除はせず保持。

## 不変ルール（禁止）

- vault 直下の既存 142 件 md ノートは **無変更**。触らない
- `.obsidian/{workspace,community-plugins,core-plugins,types,templates}.json` は変更禁止
- `.obsidian/plugins/` 配下の既存プラグインは変更禁止
- `.raw/` は **append-only**。過去ソースを書き換えない
- NOW→DONE refs/分離 運用は廃止。セッション保存は `/save` に一本化（既存 NOW/DONE は grandfather）
- 他プロジェクトでの Write/Edit が vault に誤コミットされないこと（hook の guard が保証）
- `~/.claude/` 配下と vault 配下とも symlink 不使用。スキル更新はコピー方式

## Red Flags

- vault 外プロジェクトで `wiki/` `.raw/` への書き込みが発生している
- hook が `[ -d wiki ]` ガードなしで vault 操作している
- 既存 142 ノートに git diff が出ている
- `.raw/` 配下のファイルが書き換えられている（append-only 違反）
- `rules/40-obsidian.md` の行数が 200 行を超えている（公式 200 行ガイドライン違反）

## 関連リンク

- 詳細仕様: `~/.claude/skills/wiki/references/obsidian-integration.md`
- 設計 SSoT: `~/.claude/plan.md`
- 実装記録: `~/.claude/tasks/p-a-claude-obsidian-integration.md`
- vault バックアップ: `~/.claude/state/vault-backup-20260424/`

## 優先順位

`CLAUDE.md` > 本ルール（`40-obsidian.md`）> 他 rules/ > 各スキル `SKILL.md` / `references/*.md`。
本ルールは不変ルールとカタログのみ。コマンド使用例・引数詳細・失敗時挙動は SKILL.md と references/ が正典。
