---
paths:
  - "**/Obsidian Vault/**"
  - "**/wiki/**"
  - "~/.claude/**"
---

# Vault プロジェクト構造ルール（索引・AI_adscrm 実装準拠）

> **常時注入される薄い索引**。全テーブル・YAML例・allowlist・例外条項・更新フロー・Red Flags・段階移行判定は
> **`docs/vault-project-structure-detail.md`（= `~/.claude/docs/vault-project-structure-detail.md`）を必要時 Read**。

**適用範囲**: `~/Documents/Obsidian Vault/02_Ai/<project>/` 配下の**新規プロジェクトのみ**。
既存プロジェクト（rohan/, AIera.md, ai_dashboard/ 等）は**一切変更しない**。リビング雛形: `02_Ai/AI_adscrm/`
**例外（環境ゾーン・2026-07-05〜）**: `03_ClaudeEnv/`（repo=`~/.claude`）は 02_Ai 外だが Type A として本ルール適用（MOC=`ClaudeEnv_ope.md`・frontmatter は script 生成）。詳細→ detail

## 基本原則

- **vault = 索引 + サマリー / 実体の SSoT は repo**（例外: implementation-notes は vault SSoT・§④）
- 新規プロジェクトは **MOC 1 ファイル統合構成**（`<project>_ope.md` に戦略入口・Phase 入口・施策サマリー・データソース・連携を統合）
- 同じ情報を vault と repo の両方に書かない（40-obsidian.md Anti-drift 原則）

## ①ディレクトリ & ファイル構成

- `02_Ai/<project>/` には MOC `<project>_ope.md`（索引・サマリー・file:// リンクのみ）。実体は repo 側: 戦略→`plan.md` / Phase 正本→`tasks/phase-tracker.md` / 施策本体→`docs/measures-detail.md`
- subproject MOC は group 直下に直置き（複数 md が要る時のみ `<subproject>/` を切る）。横断 MOC は `<group>_ope.md`
- 生成物: **固定名で上書き・毎日見る living →`<project>` 直下 / 日付つきで増える dated →`<group>/reports/`**（2 行判定・出典 AIads_ope・2026-07-16 global 化）。プロンプトは `<project>_INBOX.md` 1 枚（投函＋📒記録・全文保存）。定期実行のみ `prompts/scheduled/`。**`spot/`・`_README` は作らない（2026-06-26〜）**
- **registry は `wiki/meta/project-registry.md` に固定**（hook hardcode・全 group 共通）
- `wiki/` `refs/` `.raw/` は 40-obsidian.md に従い append-only。既存プロジェクトの段階移行判定（3 条件 OR）→ detail

## ②フロントマター & 命名

- 全ファイルに **6 フィールド必須**: `project` / `type` / `folder`（末尾スラッシュ）/ `categories`（親MOC wikilink）/ `last_updated` / `tags`。YAML 例・type 別追加フィールド→ detail。例外 type（concept/registry/guide）は最小要件で OK
- **汎用名単体禁止**（`plan.md`/`measures.md`/`index.md` 等）。スコープ語前置・vault 全体で basename unique・ambiguous wikilink を作らない
- **横断共通ファイル**（複数 project で同名展開されるもの）の判定は 1 問: 「**basename が path 抜きで履歴/タブ/wikilink に単独で出て、どの project か分かるか**」→ **既定 = `<project>_` prefix 必須**（`<project>_ope.md` / `<project>-impl-notes.md` / `<project>_INBOX.md` / `<project>_MEMO.md`）。bare 例外は **detail の allowlist のみ**（CLAUDE.md/README.md/plan.md/tasks/NOW.md 等のツール・別ルール予約名＝改名不可のものだけ）。機械ガード G2（重複 basename）/ G3（危険 bare wikilink）→ detail
- **`<project>_MEMO.md` の運用（全 project 共通・2026-07-16 global 化）**: ▶欄=実行プロンプト（「メモ見て」で AI 実行→結果を INBOX 📒 へ転記・状態管理も AI）／💭欄=思いつき（原文のまま・整形しない）。全文 → `docs/prompt-history-design.md`。MEMO は本人手書きの見返す資産＝下記出口ルールの退避対象外（R36 例外）

## ③Phase / MOC 構造

- **Phase 正本 = repo `<project>/tasks/phase-tracker.md`**（rules/05「実体は repo」）
  - **例外（prime_ad/prime_crm・2026-06-15〜）**: 優先順位・進捗の唯一の正本 = `tasks/NOW.md`（速い層）／ phase-tracker.md は「現在地マップ」（遅い層・優先順位とタスクは置かない）。詳細→ detail
- **vault MOC**: Phase 一行サマリー（Exit のみ）+ 施策サマリー一覧（1 行/施策: ID・一言要約・Phase・優先順位・状態）+ repo への file:// リンク索引。詳細手順・見積り・統計根拠は repo 側。施策フォーマット（H4+6要素）→ detail

## ④Anti-Bloat（肥大化防止）

- vault MOC は**司令塔**。実体（詳細手順・統計根拠・Session Handoff）を repo からコピーしない
- **自動フィード禁止（2026-06-14）**: ロボット生成ログ（`## 🔁 最新更新ログ` 等）を MOC に置かない。ライブミラー（`## 📋 Open Issues`）は MOC 最下段の自動生成ゾーンのみ許容。全文→ detail
- **例外: implementation-notes** = vault `02_Ai/<group>/<project>-impl-notes.md` が意思決定ログの唯一の正本（テンプレ `~/.claude/templates/impl-notes.md`）
- **例外: research 台帳** = 採用済み `research/` の `_summary.md` が調査台帳の vault 正本（research/ 配下限定・MOC は入口導線のみ・知見本文の二重記載禁止・リンクは path-qualified 必須。運用正本 = skill `vault-research-ledger`・2026-07-10）
- **同期義務（必須）**: repo の施策状態・優先順位・KPI を変更したセッションでは**同セッション内で** vault MOC も更新し `last_updated` を当日に（hook `vault-moc-sync-guard.sh`）。禁止基準・Red Flags 全表→ detail
- **出口ルール（退役・2026-07-14／R32-36 3層化 2026-07-16）**: vault reports/ 直下は現役 living のみ。退場する md は **「人間が後で"なぜこう決めたか／どういうルールか"を引くか」で退避先を2分**（R32「よく見る／時々見る／貯める」の3層）:
  - **vault `<project>/_archive/` へ（＝"時々見返す"層）**: **意思決定**（type: decision・裁定理由・なぜこう決めたか）・**ルールブック的な設計正本**（稼働中の設計を定義したもの）・経緯記録。**本人手書き `<project>_MEMO.md` も vault に残す（R36）**
  - **repo `reports/archive/` へ（＝"二度見ない・AI 用冷凍庫"）**: 後継に**内容が継承された調査旧版**（superseded）・定期レポートの**旧世代**（直近 2 世代のみ vault・それ以前 repo）・**時点スナップショット**・実行完了した使い捨て提案。research は台帳＋repo 移管で先取り実装済み
  **索引規約（2026-07-16）**: vault `_archive/` の実体は種類別に**台帳へ 1 行索引**（台帳＝索引・`_archive`＝実体・"どこに何の決定/ルールがあるか"を引ける R16/R19）: 調査→`research/_summary.md` / 意思決定→`wiki/meta/decisions.md`（横断アーキ判断）or MOC の決定索引（project 施策決定）/ ルールブック的（設計正本・施策定石）→`<sub>-playbook.md`・`<sub>-facts.md`。**索引なしの `_archive` 直置き禁止**。二度見ない（スナップ・会議資料・定期レポ旧世代）は索引不要＝repo `reports/archive/` へ。
  退場時は inbound を張替え（MOC 等 書換可のみ・decisions 等 append-only の歴史リンクは切れ許容）。全文→ detail §出口ルール
- **重要数値の再導出禁止（2026-07-14）**: 母数・単価等の判断数値は正本1つ（原則 repo）を参照し、各レポートで再計算して埋め込まない（実例: LINE 母数 835/1,969/9,850 並存事故）。全文→ detail §再導出禁止

## 検証 / 更新フロー

- 機械検証: `weekly-vault-audit.sh`（launchd `com.masa.vault-audit` 定期実行＋手動可・2026-07-15 訂正: 旧「launchd 未設定」は stale）: MOC 存在 / frontmatter 6 必須 / Phase 正本 / wikilink ambiguity / 自動フィード残存 / research 台帳整合（`_summary.md` 必須・bare `[[_summary]]` 禁止）
- 更新順序: ①実装 → ②本ルール → ③guide を同セッション内（「rules だけ変えて終わり」禁止）→ detail

## 優先順位

`CLAUDE.md` > `rules/40-obsidian.md` > `rules/42` > **本ルール** > 各スキル SKILL.md。詳細表 SSoT: `~/.claude/docs/vault-project-structure-detail.md`
