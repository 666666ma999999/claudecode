# Plan: claude-obsidian 統合 (Claude × Obsidian 第二の脳化)

## Why

- Obsidian vault を Claude Code の知識ベースとして機能させる（Karpathy LLM Wiki パターン）
- 既存の NOW→DONE refs/分離 運用を `/wiki` `/save` `/ingest` `/autoresearch` へ置き換える
- セッション間の文脈を `wiki/hot.md` で自動継承
- 失敗パターンを wiki に蓄積（mistakes.md + 3条件フィルタは Phase 外）

## Who

- 1 ユーザー（masaaki）、全 Claude Code セッションに影響
- 既存プロジェクト（~/Desktop/prm/* 配下の make_article/salesmtg/rohan 等）には vault 誤コミットを発生させない

## 成功基準 <a id="acceptance"></a>

1. `~/Documents/Obsidian Vault/` に `.raw/`, `wiki/{concepts,entities,sources,meta}/`, `templates/` が存在する
2. 既存 142 ノート（`~/Documents/Obsidian Vault/` 配下の既存 md）が全て残っている
3. Claude Code で `/wiki` `/save` `/ingest` `/autoresearch` `/canvas` が呼び出せる
4. vault 外のプロジェクト（例: `~/Desktop/prm/rohan`）で Write/Edit しても vault への誤コミットが発生しない
5. `~/.claude/settings.json` から `obsidian-now-done-guard.sh` と `obsidian-session-reminder.sh` が除去されている
6. `~/.claude/CLAUDE.md` の NOW→DONE refs/分離 強制ルール（L30-54 付近）が新運用に差し替えられている
7. Material Bank 182 件と lessons.md 3 ファイルが vault の `.raw/` 配下にコピーされている
8. `mcpvault` MCP サーバーが `~/.claude/settings.json` の `mcpServers` に登録され、 `claude mcp list` で起動確認できる

## 構成案

```
~/Documents/Obsidian Vault/        (既存 vault を overlay)
├── .obsidian/                      (setup-vault.sh で graph/app/appearance 上書き)
├── .raw/                           (新規: immutable sources)
│   ├── material-bank-20260424.md   (~/.claude/state/ から移行)
│   └── lessons/                    (3 lessons.md のコピー)
├── wiki/                           (新規: LLM-maintained)
│   ├── concepts/
│   ├── entities/
│   ├── sources/
│   ├── meta/
│   ├── hot.md                      (セッション間の 500 字キャッシュ)
│   ├── index.md
│   └── log.md
├── templates/                     (新規)
└── (既存 142 md ノート)             (無変更)

~/.claude/
├── skills/            (11 新規追加: autoresearch, canvas, defuddle, obsidian-*, save, wiki, wiki-*)
├── commands/          (4 新規追加: autoresearch, canvas, save, wiki)
├── agents/            (2 新規追加: wiki-ingest, wiki-lint)
├── settings.json      (hooks 4 個追加、obsidian-now-done-guard 等 2 個削除、mcpvault 追加)
└── CLAUDE.md          (Obsidian 連携セクション刷新)
```

## Phase 分解

### Phase A: Install & Vault Scaffolding <a id="phase-a"></a>

- A1. `.obsidian/` を `~/.claude/state/vault-backup-20260424/` へバックアップ
- A2. `/tmp/claude-obsidian-test/skills/*` を `~/.claude/skills/` へコピー（11 skills、衝突なし確認済み）
- A3. `/tmp/claude-obsidian-test/commands/*.md` を `~/.claude/commands/` へコピー（4 commands）
- A4. `/tmp/claude-obsidian-test/agents/*.md` を `~/.claude/agents/` へコピー（2 agents）
- A5. `bash /tmp/claude-obsidian-test/bin/setup-vault.sh ~/Documents/Obsidian\ Vault`
- A6. 検証: `ls "$VAULT/.raw" "$VAULT/wiki" "$VAULT/templates"` が成功し、既存 md 数が減っていない

**fast_verify**: `find "$VAULT" -maxdepth 2 -name "*.md" | wc -l` が 140 以上

### Phase B: Hook 再編 + CLAUDE.md 書き換え <a id="phase-b"></a>

- B1. `settings.json` の PostToolUse から `obsidian-now-done-guard.sh` を削除
- B2. `settings.json` の SessionStart から `obsidian-session-reminder.sh` を削除
- B3. `settings.json` に 4 hooks 追加:
  - SessionStart(startup|resume) → `[ -f wiki/hot.md ] && cat wiki/hot.md || true`
  - PreCompact → prompt で hot.md 再読み込み指示（hooks.json では PostCompact だが settings.json は PreCompact で代替）
  - PostToolUse(Write|Edit) → `[ -d .git ] && [ -d wiki ] && git add wiki/ .raw/ && ... || true`（vault 限定）
  - Stop → vault 内で wiki/ 変更があれば hot.md 更新プロンプト
- B4. `~/.claude/CLAUDE.md` の「Obsidian連携」セクション刷新（NOW→DONE 削除、`/wiki` `/save` ベース運用追記）
- B5. `obsidian-now-done-guard.sh` と `obsidian-session-reminder.sh` は物理削除せず `~/.claude/hooks/_deprecated/` へ退避

**fast_verify**: 別プロジェクトで Write 実行 → vault 誤コミットなし（`cd "$VAULT" && git log -1 --format=%ct` で時刻が古いまま）

### Phase C: Material Bank & lessons.md 移行 <a id="phase-c"></a>

- C1. `~/.claude/state/auto-capture-fingerprints.txt` → `$VAULT/.raw/material-bank-20260424.md` へコピー（原本保持）
- C2. `~/.claude/tasks/lessons.md` → `$VAULT/.raw/lessons/claude-home.md`
- C3. `~/Desktop/prm/chk/tasks/lessons.md` → `$VAULT/.raw/lessons/chk.md`
- C4. `~/Desktop/prm/rohan/tasks/lessons.md` → `$VAULT/.raw/lessons/rohan.md`

**fast_verify**: `ls "$VAULT/.raw/lessons" | wc -l` = 3、material-bank ファイル存在

### Phase D: mcpvault MCP 登録 <a id="phase-d"></a>

- D1. `~/.claude/settings.json` の `mcpServers` に `mcpvault` 追加
  ```json
  "mcpvault": {
    "command": "npx",
    "args": ["-y", "@bitbonsai/mcpvault"],
    "env": { "MCPVAULT_PATH": "/Users/masaaki/Documents/Obsidian Vault" }
  }
  ```
- D2. `claude mcp list` で登録確認（実行はユーザー側）

**fast_verify**: `jq '.mcpServers.mcpvault' ~/.claude/settings.json` が non-null

## 影響範囲

- `~/.claude/settings.json` （hooks/mcpServers 編集）
- `~/.claude/CLAUDE.md` （Obsidian連携セクション刷新、NOW→DONE ルール削除）
- `~/.claude/{skills,commands,agents}/` （新規追加のみ、既存上書きなし）
- `~/Documents/Obsidian Vault/.obsidian/{graph,app,appearance}.json` （setup-vault.sh が上書き）
- `~/Documents/Obsidian Vault/` 配下に `.raw/`, `wiki/`, `templates/` 新設

## 変更禁止ファイル

- `~/Documents/Obsidian Vault/` 配下の既存 md ノート（142 件）
- `~/Documents/Obsidian Vault/.obsidian/{workspace,community-plugins,core-plugins,types,templates}.json`
- `~/Documents/Obsidian Vault/.obsidian/plugins/` 配下の既存プラグイン
- `~/.claude/skills/` の既存スキル（衝突なしを事前確認済み）
- `~/.claude/commands/` の既存コマンド
- `~/.claude/hooks/` の既存 hook（obsidian-* 2 個のみ退避、他は無変更）
- `~/.claude/tasks/lessons.md` 等の lessons 原本（コピーのみ、移動しない）
- `~/.claude/state/auto-capture-fingerprints.txt`（コピーのみ、移動しない）

## Decision Log

- **2026-04-24**: Option C' (Full Integration) を採用。NOW→DONE refs/分離 は廃止 → `/save` + `/wiki` 運用へ一本化
- **2026-04-24**: 既存 .obsidian/ バックアップは `~/.claude/state/vault-backup-YYYYMMDD/` に手動削除まで保存
- **2026-04-24**: kepano/obsidian-skills はインストールしない（重複 4 件を排除すると残り 1 件のみで費用対効果低）
- **2026-04-24**: hook 配置戦略は「vault 限定 guard 付き global 登録」（`[ -d wiki ]` + `[ -d .git ]` で非 vault プロジェクトは exit 0 で安全）
