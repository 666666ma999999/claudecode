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

### Phase A-D (scaffold) — **完了済み 2026-04-24**

1. `~/Documents/Obsidian Vault/` に `.raw/`, `wiki/{concepts,entities,sources,meta}/`, `templates/` が存在する
2. 既存 142 ノート（`~/Documents/Obsidian Vault/` 配下の既存 md）が全て残っている
3. Claude Code で `/wiki` `/save` `/ingest` `/autoresearch` `/canvas` が呼び出せる
4. vault 外のプロジェクト（例: `~/Desktop/prm/rohan`）で Write/Edit しても vault への誤コミットが発生しない
5. `~/.claude/settings.json` から `obsidian-now-done-guard.sh` と `obsidian-session-reminder.sh` が除去されている
6. `~/.claude/CLAUDE.md` の NOW→DONE refs/分離 強制ルール（L30-54 付近）が新運用に差し替えられている
7. Material Bank 182 件と lessons.md 3 ファイルが vault の `.raw/` 配下にコピーされている
8. `mcpvault` MCP サーバーが `~/.claude/settings.json` の `mcpServers` に登録され、 `claude mcp list` で起動確認できる

### Phase E (feedback loop) — **着手 2026-05-22**

過去 2 回（Phase A-D 完了 4/24 + obsidian-command-center-integration 中断 5/8）が「scaffold 完成で止まる」失敗を踏んだ反省から、運用ループの観測可能 KPI を明示する。

9. **broken hook 3 本が修復済み or settings.json から参照削除**（`posttooluse-vault-warning.sh` `pretooluse-askuserquestion-guard.sh` `posttooluse-claudeenv.sh`）
10. **3 hook が settings.json に登録され、vault 外プロジェクトで no-op 動作確認済み**:
    - `wiki-recall-on-prompt.sh` (UserPromptSubmit) — decisions/mistakes 最新 5 件を context 注入
    - `wiki-auto-capture-on-stop.sh` (Stop) — 決定/教訓検出時に capture を促す
    - `wiki-dormant-warn.sh` (SessionStart) — 7 日 0 件で警告
11. **`/save decision` の保存先 = `wiki/meta/decisions.md` 単一ファイル append-only に確定**（Phase 0 で決定。Karpathy LLM Wiki layout と整合、5/22 commit `1ad9cf77` で `wiki/decisions/` dir は dissolve 済み）。`skills/save/SKILL.md:30` は既に正しく `wiki/meta/` を指している。Phase 1 で `rules/40-obsidian.md:40` と `rules/30-routing.md` の `wiki/{...,decisions,...}/` 記述を `wiki/meta/decisions.md` に統一する
12. **Phase E 完了 commit 内に `wiki/decisions/2026-05-22-rule-rollout.md`（or `wiki/meta/decisions.md` 追記）が含まれる**（meta-recursive seed）
13. **2026-05-29 時点で `git log --since="2026-05-22" wiki/decisions/ wiki/meta/{decisions,mistakes}.md --diff-filter=AM | wc -l >= 2`**（7 日後の客観 KPI）
14. **bak 3 件（`.bak-done-split` `.bak-refs-migration` `.bak-normalize-h3`）が allowlist 化 or `.gitignore` 化され、SessionStart 警告に出ない**

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

### Phase E: Feedback Loop Construction <a id="phase-e"></a>

**着手 2026-05-22。** Codex + Agent Teams 並列調査の結果、Phase A-D scaffold は完成済みだが **1 ヶ月運用停止中**（hot.md "Last Updated" 4/27、log.md 4/25）。同テーマで過去 2 回が「scaffold = 完了」と誤認して止まった事実（task.md `p-a-claude-obsidian-integration.md` 4/24 完了 / `obsidian-command-center-integration.md` 5/8 中断）を直接対策する。

参照 OSS（実装パターン流用検討対象）:
- AgriciDaniel/claude-obsidian (5.3k stars, active)
- kfchou/wiki-skills（Stop hook で自動 absorb）
- Pratiyush/llm-wiki（Karpathy LLM Wiki layout — 5/22 commit `1ad9cf77` で本 vault も同 layout に再構成済み）
- MindStudio「Self-Evolving Claude Code Memory With Obsidian Hooks」

#### Phase 0: Hook Health + simplification + baseline（目安 60 分）

- E0-1. broken hook 3 本を特定し、修復 or settings.json 参照削除
- E0-2. SSoT 確定: `/save decision` の保存先を `wiki/decisions/`（dir 復活）or `wiki/meta/decisions.md`（既存追記）に固定
- E0-3. bak 3 件処理方針確定（削除 / git ignore / allowlist）
- E0-4. simplification 判断: 既存 11 skills + 6 hooks の棚卸し、退避対象 1〜3 件を確定
- E0-5. 観測 baseline 採取: 現状 `wiki/decisions/` 等のファイル数・最終更新日を `~/.claude/state/feedback-loop-baseline.json` に記録

**fast_verify**: `bash -n hooks/*.sh` 全てパス、`jq` で settings.json 整合確認

#### Phase 1: Read+Write+Correct hook 同時導入（目安 90 分・分割禁止）

過去 2 回は「Phase 2 (rule) と Phase 3 (hook)」を分離し、hook を「後日」に追いやって失敗した。**今回は分離不可**。

- E1-1. `~/.claude/hooks/wiki-recall-on-prompt.sh` 作成（UserPromptSubmit、vault 内 cwd 限定）
- E1-2. `~/.claude/hooks/wiki-auto-capture-on-stop.sh` 作成（Stop、決定/教訓検出時に capture 促し）
- E1-3. `~/.claude/hooks/wiki-dormant-warn.sh` 作成（SessionStart、7 日 0 件で警告）
- E1-4. `~/.claude/settings.json` に 3 hook 登録（vault 外プロジェクトでの no-op を guard で保証）
- E1-5. rule 文言追加: `~/.claude/CLAUDE.md` 行動原則§Obsidian 直下に 5 行マトリクス
- E1-6. `~/.claude/rules/40-obsidian.md` を 110→140 行に拡張（hot.md 自動 cat の虚記述修正含む）
- E1-7. `~/.claude/rules/05-plan-task-md.md` 役割分担に 1 行追加（vault vs tasks/ 境界）
- E1-8. `~/.claude/rules/30-routing.md` 表に 2 行追加（判断記録 / ノート訂正）
- E1-9. **必須最終ステップ**: Phase E の最初の decision を vault に書き込む（meta-recursive seed = scaffold で止まる現象の自己治癒）

**fast_verify**: 3 hook が vault 外 cwd で exit 0（no-op）、vault 内で各イベント発火時に意図した挙動

#### Phase 2: 1 週間後の自動 audit（2026-05-29 実行予定）

- E2-1. `git log --since="2026-05-22" wiki/decisions/ wiki/meta/{decisions,mistakes}.md --diff-filter=AM | wc -l` を確認
- E2-2. wiki-dormant-warn が発火していないこと
- E2-3. 達成: ✅ done マーク / 未達: `wiki/meta/mistakes.md` に原因を書いて再設計

**Phase 後日 廃止** — 過去 2 回の「後日」= 永久未着手の同義語。

## Decision Log

- **2026-04-24**: Option C' (Full Integration) を採用。NOW→DONE refs/分離 は廃止 → `/save` + `/wiki` 運用へ一本化
- **2026-04-24**: 既存 .obsidian/ バックアップは `~/.claude/state/vault-backup-YYYYMMDD/` に手動削除まで保存
- **2026-04-24**: kepano/obsidian-skills はインストールしない（重複 4 件を排除すると残り 1 件のみで費用対効果低）
- **2026-04-24**: hook 配置戦略は「vault 限定 guard 付き global 登録」（`[ -d wiki ]` + `[ -d .git ]` で非 vault プロジェクトは exit 0 で安全）
- **2026-05-08**: kepano-obsidian-skills を再評価して導入（bilingual trigger 拡張）。Workflow 層 (claude-obsidian) と Primitive 層 (kepano) の役割分担を明確化
- **2026-05-22**: Phase A-D (scaffold) は完了済みだが運用未到達。Phase E (feedback loop) を着手。過去 2 回の失敗根因「scaffold completion bias + inform-only hook」を直接対策する設計に修正。Phase 1 で rule と hook を分離不可で同時導入する
