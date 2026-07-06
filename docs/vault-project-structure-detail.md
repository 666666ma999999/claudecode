# Vault プロジェクト構造ルール — 詳細表（rules/41 の SSoT 委譲先）

> **これは `rules/41-vault-project-structure.md` の詳細版**。rules/41 は常時注入される薄い索引で、
> §①②③④ の load-bearing な要点と hook grep 依存文字列のみを保持する。本ファイルは
> **必要時に Read** する詳細（全テーブル・例外条項・更新フロー・Red Flags）。
> （`rules/30-routing.md` → `docs/routing-table.md`、`rules/42` → `docs/file-placement-detail.md` と同型の分離・2026-06-14）

**適用範囲**: `~/Documents/Obsidian Vault/02_Ai/<project>/` 配下の**新規プロジェクトのみ**。
既存プロジェクト（rohan/, AIshift.md, AIera.md, ai_dashboard/ 等）は**一切変更しない**。
**例外（環境ゾーン・2026-07-05〜）**: `03_ClaudeEnv/`（repo = `~/.claude` 自身）は 02_Ai 外だが連携ゾーン=**Type A（repo 連携）**として本ルールを適用する。実体マッピングは 02_Ai の `plan.md`/`tasks/phase-tracker.md`/`docs/measures-detail.md` 三連ではなく、`~/.claude` 実体（`rules/`・`hooks/`・`skills/`・`scripts/`）＋ vault 索引カタログ（`ClaudeEnv_ope.md`=旧 `_README.md`・各 `*-catalog.md`）に読み替える。索引・frontmatter 6 必須は `~/.claude/scripts/update_claudeenv.py` が自動生成（手編集は再生成で上書き）。SessionStart で drift-watch P0＋手書き `## NOW/懸案` を注入（cwd=~/.claude 限定）。
リビングリファレンス実装: `file:///Users/masaaki_nagasawa/Documents/Obsidian%20Vault/02_Ai/AI_adscrm/`

---

## ①ディレクトリ & ファイル構成（詳細）

新規プロジェクトは **MOC 1 ファイル統合構成** で開始する (案 X2・2026-05-17 改訂・rules/05 純化方針に整合):

```
02_Ai/<project>/
  <project>_ope.md        # MOC 1 ファイルに全要素統合 (戦略入口 + Phase 入口 + 施策サマリー索引 + データソース + 連携)
```

**実体は全て repo 側**・vault は索引・サマリー・file:// リンクのみ:
- 戦略 → `repo/<project>/plan.md`
- Phase 正本 → `repo/<project>/tasks/phase-tracker.md`
- 施策本体 → `repo/<project>/docs/measures-detail.md`
- 施策仕様 → `repo/<project>/docs/rationales/*.md`

実装例 (リビング雛形): [`02_Ai/AI_adscrm/AIads_ope.md`](file:///Users/masaaki_nagasawa/Documents/Obsidian%20Vault/02_Ai/AI_adscrm/AIads_ope.md)

- **subproject MOC は group 直下に直置き** (1 ファイルしかない場合にサブディレクトリを切らない・空に近い階層を作らない)。例: `02_Ai/AI_adscrm/AIads_ope.md` / `02_Ai/AI_adscrm/AIcrm_ope.md`
- subproject に **複数の md ファイルが必要になった場合のみ** `<subproject>/` ディレクトリを切る (例: `02_Ai/AI_adscrm/AIads/AIads_ope.md` + `02_Ai/AI_adscrm/AIads/refs/`)
- 横断 MOC が必要になったら `<group>_ope.md`（group 直下）を追加し、各 subproject の `*_ope.md` をリンクする
- 実装例 (group 構造の完成形): [`02_Ai/AI_adscrm/`](file:///Users/masaaki_nagasawa/Documents/Obsidian%20Vault/02_Ai/AI_adscrm/)（`AIads_ope.md` + `AIcrm/AIcrm_ope.md` の 2 subproject MOC を横断 `adscrm_cross.md` で束ねる構造。横断 MOC の実名は `adscrm_cross.md`・2026-06-13 確認）
- subproject 配下の生成物: dated レポートは `<group>/reports/`、プロンプトは `<project>/prompts/<project>_INBOX.md` 1 枚（投函＋`## 📒 記録`・全文保存）に集約。定期実行のみ `prompts/scheduled/`（launchd）。**`spot/` 別ファイル・`_README` は作らない（2026-06-26〜・[[decisions]]）**（group root には MOC・playbook・impl-notes・living draft のみ残す。2026-06-13 AI_adscrm で適用）
- **registry の置き場所は `wiki/meta/project-registry.md` に固定** (vault 全体の横串インデックスとして `wiki/meta/` に集約・hook `~/.claude/hooks/sessionstart-project-registry.sh:26` で hardcode・全 group 同一 registry に追記)
- `wiki/`, `refs/`, `.raw/` は 40-obsidian.md のルールに従い append-only

### 既存プロジェクトの段階移行判定 (3 条件・OR)

既存プロジェクト (`02_Ai/rohan/` `AIera.md` 等) を本ルールに移行するかの判定は以下 3 条件の **OR** で発火:

1. 新規 plan / measures / progress / strategy を追加する予定がある
2. Phase 表 (`## Phase 進捗` 等) が 2 箇所以上に分散している
3. wikilink ambiguity が検出されている (`plan.md` `measures.md` 等の汎用名が複数存在)

3 条件のいずれも該当しない場合は**移行禁止** (5/8 ai_dashboard 同型「やった方が良さそう → 頓挫」回避)。

---

## ②フロントマター & 命名（詳細）

全ファイルに以下 6 フィールドを必ず含める（**AI_adscrm 実装準拠**・2026-05-16 改訂）:

```yaml
---
project: <project-name>            # 例: prime_ad / prime_crm
type: <note-type>                  # moc / plan / measures-index / progress / implementation-notes / stub / concept / registry / hub
folder: "02_Ai/<project>/"         # ← vault 相対パス・末尾スラッシュ必須・Dataview/Bases クエリ用
categories:                        # ← 所属 MOC への wikilink (kepano 式)
  - "[[<parent-MOC>]]"
last_updated: YYYY-MM-DD
tags:
  - project/<project-name>
  - type/<note-type>
---
```

### type 別追加フィールド (任意)

- **plan**: `phase` / `goal_deadline` / `target_cv` `target_cpa` `target_budget` 等
- **progress**: `phase` / `current_cv` `current_cpa` `current_budget` 等
- **measures-index**: `updated`
- **moc** (データ管理含む場合): `data_root` / `processed_root` / `lineage_doc` / `sources_doc` (全て file:// URI)
- **linked**: 関連 MOC・主要ノートへの wikilink 配列 (cross-link)

### 命名禁止

`plan.md` / `measures.md` / `strategy.md` / `progress.md` / `index.md` 等の汎用名単体は禁止。
必ずスコープ語を前置すること（例: `prime ad strategy.md`, `AIads_ope.md`）。
vault 全体でファイル名 unique を保証し、`[[plan]]` 等の ambiguous wikilink を作らない。

### 例外 type の最小要件 (vault 全体に関わる特殊 type)

以下の特殊 type は 6 フィールド全部は不要・最小要件で OK:

- **concept** (vault コンセプト定義): 最小 `type:` + `title:` + `updated:` (project / categories / tags 任意)
- **registry** (プロジェクト住所録・hook 連動): 最小 `type:` + `title:` + `updated:` (project / categories / tags 任意)
- **guide** (人間向けガイド): 最小 `type:` + `folder:` + `last_updated:` (project / categories / tags 任意)

これら以外の全 type (`moc` / `plan` / `measures-index` / `progress` / `stub` / `hub` 等) は 6 フィールド必須。

### 横断共通ファイルの命名（Identity must survive a flat surface・2026-06-30 / agent team + Codex 敵対レビュー済み・詳細 [[decisions]]）

複数 project で同名展開されるファイル（`plan.md`/`tasks/NOW.md`/`phase-tracker.md`/`lessons.md`/`docs/*.md` 等。**旧 `_INBOX.md`/`_MEMO.md` は 2026-06-30 に `<project>_INBOX.md`/`<project>_MEMO.md` へ改名済**）の命名は **保存場所でなく「参照面」で判定**。判定テスト 1 問:

> **basename が path 抜きで履歴(claude-mem)/タブ/wikilink に単独で出て、どの project か分かるか。**

- **既定＝ scope-prefix 必須**（`<project>_ope.md` / `<project>-impl-notes.md` / `<project>_INBOX.md` / `<project>_MEMO.md` / `<scope>-<descriptor>.md`）。新規ファイルは原則これ。「unique・汎用名禁止」がこの既定。
- **bare 例外＝下の allowlist のみ**（リネーム不能な名前だけ）。例外は「除外条項で曖昧を許す」のでなく、**機械ガード(G1〜G3)で識別を別途担保**する前提（除外条項で §② を骨抜きにしない）。

**bare-allowlist（canonical bare 維持・prefix 禁止）**:

| 種別 | 名前 | bare 理由 |
|---|---|---|
| ツール予約 | `CLAUDE.md` / `README.md` / `AGENTS.md` | Claude Code/GitHub/Codex が固定解決・改名不可 |
| rules/05・§③ 固定 | `plan.md` / `tasks/NOW.md` / `tasks/phase-tracker.md` / `tasks/lessons.md` | 別ルールが `<root>/` 固定名を規約化（外部ツール/別ルールが要求＝改名不可） |
| auto-gen/予約 | `_index.md` / `hot.md` / `decisions.md` / `mistakes.md` / `project-registry.md` | N-4・hook hardcode（既出） |
| 横断HQ | `MASA_HQ.md`（vault root 直下・唯一） | decisions 2026-07-06 起票。入口リンク集+早見表のみ（**TODO は各 project 司令塔の管轄・HQ に置かない**）・有人更新のみ・1週間トライアル（〜7/13 開かれなければ撤去し本行も削除） |

> 注: プロンプト箱・メモ帳は**かつて bare（`_INBOX.md`/`_MEMO.md`）だったが**、それらを握るのは自前スクリプト3つ(`vault-spot-runner.sh`/`weekly-vault-audit.sh`/月次棚卸し)だけ＝外部ツール非依存のため、2026-06-30 に `<project>_INBOX.md`/`<project>_MEMO.md` へ改名し**スクリプト側を `*_INBOX.md` グロブへ追従**。bare 例外から外れ既定(prefix)へ移行。

allowlist 外で横断表示されうるファイル（reports / docs / findings 等）は **prefix 必須**。新規横断ファイルは「名前が外部固定か？ → yes=allowlist 追記して bare / no=`<project>-` prefix」で 1 問判定。

**機械ガード**: G2 vault 重複 basename 検出（allowlist 除外）/ G3 危険 bare wikilink（`[[plan]]`/`[[NOW]]`/`[[phase-tracker]]` 等）検出。`weekly-vault-audit.sh` へ追加候補。**G1（claude-mem title に `<project>:` 強制）は保留**＝claude-mem は第三者プラグインで、履歴 DB への外部書込は「稼働中プロセスの書き戻し」事故([[mistakes]])に当たり脆い。改名できない `plan.md`/`NOW.md`/`phase-tracker.md` の履歴識別が課題として残るが、`_INBOX`/`_MEMO` は改名で恒久解決済（G1 不要化）。

---

## ③Phase / MOC 構造（詳細）

- **Phase 正本**: **repo `<project>/tasks/phase-tracker.md`** (rules/05 「実体は repo」原則・2026-05-17 改訂)
  - **例外（prime_suite・2026-06-12〜 / 2026-06-15 精製）**: prime_ad/prime_crm は **時間スケールで 2 層分離**。**優先順位・やること・進捗（TODO/行動・速い）= `tasks/NOW.md`**（スコア式・**唯一の優先順位正本**）／ **Phase の地図（大きな節目・Exit・今ここ・遅い）= `tasks/phase-tracker.md`**（凍結解除し「現在地マップ」に再生・**優先順位とタスクと施策リストは置かない**）。NOW の各タスクは `Ph` タグで地図上の位置を指す。凍結前スナップショットは `tasks/archive/phase-tracker-presplit-*.md`。他 project は従来どおり phase-tracker.md が正本
- **vault MOC** (`<project>_ope.md`): Phase 一行サマリー (Exit 条件のみ) + repo phase-tracker (prime_suite は NOW.md) への file:// リンク
- **施策本体**: **repo `<project>/docs/measures-detail.md`** (32+ 件詳細)
- **vault MOC**: 施策サマリー一覧 (1 行/施策: ID・一言要約・Phase・優先順位・状態) + Phase 別 file:// リンク索引。詳細手順・寄与/CPA 見積り・統計根拠など実体は repo 側 (下記 ④「施策サマリーは MOC に書く」節)
- **施策フォーマット (repo 側ガイドライン・参考)**: 各施策は H4 + 6 要素 (何をするか / なぜやるか / 期待効果 / 使用データ / 📌 サマリー / 詳細リンク)

```
### 施策名
- **何をするか**: ...
- **なぜやるか**: ...
- **期待効果**: | 指標 | 現状 | 目標 |（表形式）
- **使用データ**: `file:///...` 絶対パス
- **サマリー**: H5 (`#####`) で 3-5 行
- **詳細リンク**: `[[関連ノート]]` or 外部 URL
```

- `*_ope.md` はサブプロジェクト MOC。司令塔として現状俯瞰・施策サマリー一覧・優先順位・クイックリンクを持つ（詳細実体は持たない・下記 ④ 参照）

---

## ④Anti-Bloat（肥大化防止・詳細）

### 自動フィード禁止（2026-06-14）

ロボット生成ログ（`## 🔁 最新更新ログ` 等）は MOC に**置かない・生成しない**。git log + `wiki/meta/decisions.md`（毎セッション注入）+ claude-mem の劣化コピーで人間も読み返さず、`rules/20` Dual-Path/SSoT 違反。AI の最近の活動把握は本物 SSoT に委ねる。ライブミラー（`## 📋 Open Issues`）は許容するが **MOC 最下段の「自動生成ゾーン」**に置き、人間向け司令塔セクションより上に出さない（`sync-vault-summary.py cmd_issues` が末尾挿入）。`weekly-vault-audit.sh` が MOC 内の `## 🔁 最新更新ログ` 残存を回帰検出する。

**vault = 索引 + 施策サマリー。コンテンツ実体の SSoT は repo 側**:
- plan.md / task.md / spec の実体は **repo 配下**に置く
- vault ノートは `file://` リンクまたは `[[wikilink]]` でポイントするだけ
- 同じ情報を vault と repo の両方に書くことは**禁止**（40-obsidian.md Anti-drift 原則）

### 情報の正本一箇所原則 (案 X2・2026-05-17 改訂)

**vault は索引 + 施策サマリー・実体は repo**（実体側の例外: implementation-notes ノート・下記専用節）。以下の情報の正本は repo 側:

| 情報 | 正本 (repo) | vault MOC の扱い |
|---|---|---|
| 戦略 / Why / 成功基準 | `repo/<project>/plan.md` | 主要 KPI 表 (正式 / 留保) + file:// リンク |
| Phase 状態 / Exit 条件 / 期間 | `repo/<project>/tasks/phase-tracker.md` | 1 行 Phase サマリー + file:// リンク |
| 施策本体 (詳細手順・統計根拠) | `repo/<project>/docs/measures-detail.md` | **施策サマリー一覧 (1 行/施策) + 優先順位** + Phase 別 file:// リンク索引 (下記専用節) |
| 施策仕様 (統計根拠書) | `repo/<project>/docs/rationales/*.md` | 主要施策のみ link |
| データソース系譜 | `repo/<project>/docs/data_lineage.yaml` | カテゴリ別構造表 + link |
| データ取得履歴 | `repo/<project>/docs/data-sources.md` | 主要データ表 + link |
| Session Handoff | `repo/<project>/tasks/phase-tracker.md` | (vault には書かない) |
| Implementation Notes (意思決定ログ) | **例外: vault `02_Ai/<group>/<project>-impl-notes.md`** | vault が SSoT。MOC は `[[<project>-impl-notes]]` で索引。詳細は下記専用節 |

### 施策サマリーは MOC に書く (summary / 実体 の線引き・2026-05-20 改訂)

vault MOC (`<project>_ope.md`) は**司令塔**として、施策の**サマリー一覧と優先順位を保持する**。「司令塔に実体コピー禁止」原則は維持しつつ、サマリー (要約) と実体 (詳細) を以下で線引きする:

| 種別 | 置き場所 | 含めてよい内容 |
|---|---|---|
| **施策サマリー** (MOC に書く) | vault MOC | 施策 ID / 一言要約 (1 行) / Phase / 優先順位ランク / 状態 (絵文字 1 つ) / 現状ステータス俯瞰 (主要 KPI の最新値) / NOW・次アクション |
| **施策実体** (MOC に書かない) | repo `measures-detail.md` / `measure-impact-table.md` / `rationales/` / `phase-tracker.md` | 詳細手順・寄与 CV 見積りレンジ・CPA 影響・統計根拠・実施日・Session Handoff |

**drift 防止の同期義務 (必須)**: repo `phase-tracker.md` / `measures-detail.md` の施策状態・優先順位・一言要約・主要 KPI を変更したセッションでは、**同セッション内で** vault MOC のサマリーも更新し `last_updated` を当日にする (CLAUDE.md「司令塔リンク索引の手動更新」原則の拡張)。「repo だけ更新して MOC 据え置き」は禁止 (2026-05-18→05-20 で実際に発生した drift の再発防止)。

**サマリーに数値見積り (寄与 CV / CPA レンジ) を載せる場合**: 正本は repo `measure-impact-table.md`。MOC には参考値として転記してよいが、上記同期義務の対象に含める。

### implementation-notes ノート (vault 実体・例外条項・2026-05-20)

意思決定ログ (Thariq Shihipar 提唱の implementation-notes) は **vault 連携プロジェクトに限り vault を SSoT とする**。理由: 記事の目的は「人間がレビューして初めて価値が出る」こと。レビューは Obsidian で行うが repo md は Obsidian が描画できず可視化されない。実体を vault に 1 つだけ持つため drift は発生しない。

- **置き場所**: `02_Ai/<group>/<project>-impl-notes.md` (MOC `<project>_ope.md` と同階層)
- **SSoT**: 本ノートが意思決定ログの唯一の正本。vault 連携プロジェクトでは repo task.md の `## Decision Log` は使わない (非 vault プロジェクトは従来どおり task.md Decision Log)
- **MOC との接続**: impl-notes ノートの `categories: [[<project>_ope]]` frontmatter が MOC への逆リンクになる (Obsidian のバックリンク/グラフに自動表示)。**MOC 本体の編集は不要** (registry が「非編集」とする凍結 MOC でも適用可)
- **frontmatter**: `type: implementation-notes`・6 フィールド必須
- **テンプレート**: `~/.claude/templates/impl-notes.md`
- **書き手**: Claude Code が実装中に直接追記 (vault パスは編集 ALLOW リスト内)
- **構造**: `## Decision Log` 表 (task.md と同じ「仕様差分」列 on-spec/interpreted/deviation/open-question) + `## Open Questions` (未解決の要確認)
- **承知の上のトレードオフ**: repo コミット/PR に判断ログは乗らない。vault は obsidian-git で別途版管理される

違反の典型 (5/8 / 5/14 同型・要警戒):
- vault に Phase 表・施策本文・成功基準など実体を書く (= rules/05 違反)
- vault progress.md / strategy.md / measures.md を独立ファイルとして作成・運用 (二重管理発生)
- strategy.md に `## repo 側正本` 表が独立、Phase 別索引に絵文字状態 (`🟢` 等) や期間直書き

検証: `weekly-vault-audit.sh` (MOC 1 ファイル前提・将来拡張で機械検出予定・現状は手動 review 併用)。

**ファイル追加の禁止基準**:
- 既存ファイルのどれかに H2 セクション追加で収まる場合は新規ファイルを作らない
- "整理のための整理" ノート（index, summary, overview 等の汎用名）は作らない

**Red Flags**:
- `progress.md` 以外のファイルに Phase 表がある（二重管理）
- `folder:` プロパティ未設定のファイルがある
- 汎用名ファイル（`plan.md` 等）が vault に存在する
- vault ノートに spec/実装詳細が直接書かれている（repo に書くべき）

---

## 更新フロー (rules/41 自身の変更ルール)

### 標準順序: 実装 → rules/41 → guide

AI_adscrm/ 実装変更時は **同セッション内で**: ①実装 → ②rules/41 (不変化したルールだけ) → ③guide (リンクと説明のみ) の順で追従。

### rules 先行の例外節

`rules/41` を先に変更してから実装を migration するケース (例: 新必須フィールド追加で既存実装が違反になる) は、**同 PR / 同セッション内で実装 migration まで完了する場合に限り許可**。「rules だけ変えて終わり」は禁止 (5/14 Control Tower Sync 同型回避)。

### 機械的 drift 検知

`~/.claude/hooks/weekly-vault-audit.sh` が週次で ④章 grep 検証を実行 (launchd `com.masa.vault-audit.plist`)。違反検出時は `sessionstart-vault-audit-warning.sh` が次回 SessionStart で warning 注入。検証内容: (1) MOC `_ope.md` 存在 (2) frontmatter 6 必須フィールド (例外 type 除く) (3) Phase 正本 (4) wikilink ambiguity 検出。
