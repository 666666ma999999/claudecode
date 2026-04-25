# Obsidian 連携ルール（claude-obsidian 方式）

CLAUDE.md の「行動原則」§Obsidian の詳細仕様。2026-04-24 以降の運用ルール。
Vault パス: `~/Documents/Obsidian Vault/`。claude-obsidian 11 スキル + 4 コマンド + 2 agent を `~/.claude/{skills,commands,agents}/` に導入済み。

## 基本操作

| コマンド | 用途 |
|---|---|
| `/wiki` | vault セットアップ / scaffold / 再開 |
| `/save [name]` | 現在の会話を wiki ノートとして保存 |
| `/ingest <file\|url>` | ソースを `.raw/` に取り込み → wiki/ に自動整理 |
| `/autoresearch <topic>` | iterative web research → wiki/ に filing |
| `/canvas` | 視覚キャンバスの open/create/add |
| `lint the wiki` | orphan / dead link / gap 検出 |

## 自動挙動（hooks）

- **SessionStart (startup|resume)**: `wiki/hot.md` を自動 cat（vault 外は no-op）
- **PostToolUse (Write|Edit)**: vault かつ `.git` 存在時のみ `wiki/` `.raw/` を auto-commit（他プロジェクトでは no-op）
- **Stop**: `wiki/` 変更があれば `hot.md` 更新プロンプトを injection
- **PreCompact**: `wiki/hot.md` を再読み込み（context compaction 対策）

## 原則

- vault 直下の既存 md（142 件）は無変更・触らない
- NOW→DONE refs/分離 運用は 2026-04-24 に廃止。以降は `/save` に一本化
- 既存 NOW/DONE エントリは grandfather 扱いで無編集保持
- `.raw/` 配下は append-only（過去ソースを書き換えない）
- `wiki/` 配下は LLM 自動メンテナンス領域（人手編集も可、ただし hook で auto-commit 発生）

## vault 構造

- `.raw/` — immutable sources（取り込み元の生データ）
- `wiki/{concepts,entities,sources,meta}/` — LLM が整理する知識ベース
- `wiki/hot.md` — 500 字 session cache（SessionStart で自動読み込み）

## 関連スキル

`wiki` / `save` / `wiki-ingest` / `autoresearch` / `wiki-query` / `wiki-lint` / `obsidian-markdown` / `obsidian-bases` / `canvas` / `defuddle` / `wiki-fold`

## 優先順位

`CLAUDE.md` > 本ルール（`40-obsidian.md`）> 他 rules/ > スキル。
