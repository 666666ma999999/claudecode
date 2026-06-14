# Vault プロジェクト構造ルール（索引・AI_adscrm 実装準拠）

> **常時注入される薄い索引**。全テーブル・例外条項・更新フロー・Red Flags・段階移行判定は
> **`docs/vault-project-structure-detail.md`（= `~/.claude/docs/vault-project-structure-detail.md`）を必要時 Read**。
> （`rules/30-routing.md`→`docs/routing-table.md`、`rules/42`→`docs/file-placement-detail.md` と同型の分離・2026-06-14 スリム化）

**適用範囲**: `~/Documents/Obsidian Vault/02_Ai/<project>/` 配下の**新規プロジェクトのみ**。
既存プロジェクト（rohan/, AIera.md, ai_dashboard/ 等）は**一切変更しない**。
リビング雛形: [`02_Ai/AI_adscrm/`](file:///Users/masaaki_nagasawa/Documents/Obsidian%20Vault/02_Ai/AI_adscrm/)

---

## 基本原則（これだけ守れば大筋 OK）

- **vault = 索引 + サマリー / 実体の SSoT は repo**（例外: implementation-notes は vault SSoT・§④）
- 新規プロジェクトは **MOC 1 ファイル統合構成**（`<project>_ope.md` に戦略入口・Phase 入口・施策サマリー・データソース・連携を統合）で開始
- 同じ情報を vault と repo の両方に書かない（40-obsidian.md Anti-drift 原則）

---

## ①ディレクトリ & ファイル構成

```
02_Ai/<project>/
  <project>_ope.md   # MOC（司令塔）= 索引・サマリー・file:// リンクのみ
```

- 実体は全て repo 側: 戦略→`repo/<project>/plan.md` / Phase 正本→`repo/<project>/tasks/phase-tracker.md` / 施策本体→`repo/<project>/docs/measures-detail.md`
- subproject MOC は group 直下に直置き。複数 md が要る時のみ `<subproject>/` を切る。横断 MOC は `<group>_ope.md`（実名例: `adscrm_cross.md`）
- subproject 生成物: dated レポート→`<group>/reports/`、定期実行プロンプト→`<group>/prompts/` に集約（group root は MOC・playbook・impl-notes・living draft のみ。2026-06-13〜）
- **registry の置き場所は `wiki/meta/project-registry.md` に固定**（vault 全体の横串インデックス・hook `sessionstart-project-registry.sh` で hardcode・全 group 同一 registry に追記）
- `wiki/` `refs/` `.raw/` は 40-obsidian.md に従い append-only
- 既存プロジェクトの段階移行判定（3 条件 OR）→ 詳細は docs/

---

## ②フロントマター & 命名

全ファイルに以下 **6 フィールド必須**（AI_adscrm 実装準拠）:

```yaml
---
project: <project-name>            # 例: prime_ad / prime_crm
type: <note-type>                  # moc / plan / measures-index / progress / implementation-notes / stub / concept / registry / hub
folder: "02_Ai/<project>/"         # vault 相対パス・末尾スラッシュ必須・Dataview 用
categories:
  - "[[<parent-MOC>]]"             # 所属 MOC への wikilink (kepano 式)
last_updated: YYYY-MM-DD
tags:
  - project/<project-name>
  - type/<note-type>
---
```

- **命名禁止**: `plan.md` / `measures.md` / `strategy.md` / `progress.md` / `index.md` 等の汎用名単体は禁止。スコープ語を前置（例 `AIads_ope.md`）。vault 全体でファイル名 unique を保証し ambiguous wikilink を作らない
- **例外 type**（6 フィールド全部は不要）: `concept` / `registry` / `guide` は最小要件で OK
- type 別追加フィールド（plan の `phase`/`target_*` 等）→ 詳細は docs/

---

## ③Phase / MOC 構造

- **Phase 正本 = repo `<project>/tasks/phase-tracker.md`**（rules/05「実体は repo」）
  - **例外（prime_suite・2026-06-12〜）**: prime_ad/prime_crm は phase-tracker.md を**凍結**し、生きた正本を **`tasks/NOW.md`** に一本化。当 group の Phase を見る時は NOW.md。他 project は従来どおり phase-tracker.md
- **vault MOC**: Phase 一行サマリー（Exit 条件のみ）+ 施策サマリー一覧（1 行/施策: ID・一言要約・Phase・優先順位・状態）+ repo への file:// リンク索引。詳細手順・寄与/CPA 見積り・統計根拠は repo 側
- 施策フォーマット（H4 + 6 要素）→ 詳細は docs/

---

## ④Anti-Bloat（肥大化防止）

- vault MOC は**司令塔**＝施策サマリー一覧と優先順位を持つ。**実体（詳細手順・統計根拠・Session Handoff）は repo にコピーしない**
- **例外: implementation-notes ノート** = vault `02_Ai/<group>/<project>-impl-notes.md` が意思決定ログの唯一の正本（vault 連携プロジェクトのみ・`type: implementation-notes`・テンプレ `~/.claude/templates/impl-notes.md`）
- **drift 防止の同期義務（必須）**: repo `phase-tracker.md` / `measures-detail.md` の施策状態・優先順位・KPI を変更したセッションでは**同セッション内で** vault MOC のサマリーも更新し `last_updated` を当日にする。「repo だけ更新して MOC 据え置き」は禁止（hook `vault-moc-sync-guard.sh` が reminder）
- ファイル追加の禁止基準・違反の典型・Red Flags・正本一箇所の全テーブル → 詳細は docs/

---

## 検証 / 更新フロー

- **機械検証**: `bash ~/.claude/hooks/weekly-vault-audit.sh`（週次 launchd）。検証内容: (1) MOC `_ope.md` 存在 (2) frontmatter 6 必須フィールド（例外 type 除く）(3) Phase 正本 (4) wikilink ambiguity。違反時は次回 SessionStart で warning 注入
- **更新順序**: ①実装 → ②本ルール（不変化したルールだけ）→ ③guide の順で同セッション内に追従。「rules だけ変えて終わり」禁止 → 詳細は docs/

## 関連ルール / 優先順位

本ルールは `rules/40-obsidian.md` §index が参照する **vault 構造の専門則**（Obsidian 連携の入口は 40）。
優先順位: `CLAUDE.md` > `rules/40-obsidian.md` > `rules/42` > **本ルール** > 各スキル SKILL.md。
詳細表 SSoT: `~/.claude/docs/vault-project-structure-detail.md`。
