# Obsidian 連携ルール（claude-obsidian 方式）

CLAUDE.md「行動原則 §Obsidian」の不変ルール定義。2026-04-24 以降の運用。
詳細仕様（コマンド使用例・vault 構造・スキル一覧・典型ワークフロー）は `~/.claude/skills/wiki/references/obsidian-integration.md` を参照。

## 適用条件

- 対象 vault: `~/Documents/Obsidian Vault/`
- 構成要素: 11 skills + 4 slash commands + 2 agents + 4 hooks + 1 MCP server (mcpvault)
- vault 外プロジェクトでは全 hook が no-op（`[ -d wiki ] && [ -d .git ]` ガードによる）

## 基本コマンド（カタログ）

| コマンド | 用途 | 詳細 |
|---|---|---|
| `/wiki` | vault セットアップ確認 / scaffold / 再開 | `skills/wiki/SKILL.md` |
| `/save [name]` | 会話を wiki ノート保存 | `skills/save/SKILL.md` |
| `/canvas [op]` | Canvas 操作 | `skills/canvas/SKILL.md` |
| `/autoresearch <topic>` | 自律 web 調査 | `skills/autoresearch/SKILL.md` |
| `ingest <file\|url>` | ソース取込み | `skills/wiki-ingest/SKILL.md` |
| `lint the wiki` | リンク健全性検証 | `skills/wiki-lint/SKILL.md` |

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
