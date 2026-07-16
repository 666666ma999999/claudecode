# ファイル種別 配置仕分け — 詳細表（rules/42 の詳細版）

> **これは `rules/42-file-type-placement.md`（常時ロードの薄い索引）の詳細コンパニオン**。
> 71 種の完全な配置表・備考・命名規約・根拠・適用順序の SSoT。
> 必要時のみ Read する（`30-routing.md` → `docs/routing-table.md` と同じ分離パターン・2026-05-30 分離）。
> ルール本体・優先順位・対象外節は `rules/42-file-type-placement.md` を参照。

**確定日**: 2026-05-24 (Phase 1 完了・Active 化: 2026-05-25)
**位置づけ**: Claude ↔ Obsidian 連携プロジェクトでの **ファイル種別 71 種の配置 SSoT** (Active・Phase 2+5 hook 連動・O 群=仕事フォルダ横断は 2026-07-10 追加)
**関連 rules**:
- `rules/40-obsidian.md` — vault 全体運用（claude-obsidian、wiki/、meta/）
- `rules/41-vault-project-structure.md` — Type A 詳細（MOC 構造 / frontmatter / drift 防止）
- `rules/05-plan-task-md.md` — plan.md / task.md 役割分担

**vault サマリ版**: `~/Documents/Obsidian Vault/wiki/meta/file-placement-rules.md`（叩き台フォーマットの簡潔版）

---

## 運用ステータス（履歴）

> **✅ Status: Active (2026-05-25 Phase 2 連動運用中)**
>
> Phase 2 実装完了 (Stop hook `stop-vault-summary-suggest.sh` + skill `/sync-vault-summary` + helper `sync-vault-summary.py` + settings.json 登録)。本ルールは運用導線に接続済 (`~/.claude/state/vault-cc-enabled` flag gate 連動)。
>
> **段階的展開フェーズ**:
> - Phase 1 (完了): Draft 解除 + 欠落種別 M 追記 + CLAUDE.md/30-routing に参照リンク追加
> - Phase 2 (完了): Stop hook + skill + script 実装 + 動作テスト
> - Phase 3 (完了): weekly-vault-audit 拡張 (検証 5 K-3 project 内 wiki/ 廃止 + 検証 6 repo 専用ファイルの vault 流入検出)
> - Phase 5 (完了・2026-05-25): H-6 issue tracking (GitHub Issues SoT) 採用・SessionStart hook `sessionstart-github-issues.sh` + `sync-vault-summary.py issues` 実装・3 MOC に `## 📋 Open Issues` 初期化
> - Phase 4 (次セッション以降): 全 9 project の CLAUDE.md に Vault Integration セクション展開
>
> **既知の運用上の留意点** (enforcement なし・warning レベルのみ):
> - 53 種仕分けは AI_adscrm (prime_ad + prime_crm) + make_article + vault AI_adscrm 監査で 100% カバー。rohan FE+BE / aiimg / autopost 等は 53 種に該当しないファイルあり → 対象外節 (rules/42 末尾) で明示
> - hook hardcode 残課題 (H-1 リネーム / H-4 spec-pulse 出力先 / K-3+K-4 audit パス) は次セッション以降
> - decisions.md 2026-05-25 entry「rules/42 自動展開を Phase 2 から段階的に着手」参照

---

## 基本原則（叩き台 [Finalized] 準拠）

- **vault** = サマリ + 索引（人間レビュー動線）
- **repo** = 全文 SSoT（コード・実データ・git 履歴一体管理）
- **例外**: implementation-notes は vault SSoT（rules/41 §④例外条項）

## プロジェクトタイプ

| タイプ | 説明 | 例 |
|---|---|---|
| **A: repo 連携** | 分析・コード・データを repo で運用、vault は索引 | AI_adscrm (prime_ad + prime_crm) |
| **B: vault-only** | repo を持たず vault 内に全て | 知識ベース、PM ToDo、軽量分析 |
| **C: 単発ノート** | 1 ファイル完結 | AI_LP.md 等の単独 .md |

判定: ① 実コード or 実データを持つ → A / ② plan + 施策 + 分析 + 進捗のうち 2 種以上を継続運用 → B / それ以外 → C

---

## 0. 既決定（叩き台より・8 種）

| # | 種別 | vault | repo | 全文側 |
|---|---|---|---|---|
| 0-1 | 知識 / GTD / 日記 / PM ToDo | project root 直下 | — | **vault** |
| 0-2 | draft | project root | — | **vault** |
| 0-3 | 仕様 | 住所 + サマリ | 全文 | **repo** |
| 0-4 | 施策 | 住所 + 1 行サマリ | 全文 | **repo** |
| 0-5 | 計画 / 施策ファイル | サマリ | 全文 | **repo** |
| 0-6 | 分析 | 住所 + サマリ + 図解 | 実データ + 詳細 | **repo** |
| 0-7 | X 投稿ネタ | `wiki/x-article-stock.md`（cross） | — | **vault** |
| 0-8 | wiki 知識化 | `wiki/` 配下（cross） | — | **vault** |

### §0-6 補足: `research/{,_raw,_archive}` 3 階層化の適用条件（2026-05-27 追加）

`02_Ai/<group>/<sub>/research/{,_raw,_archive}/` の per-project 3 階層化は、以下を **全て満たす場合のみ** 採用する:

- **Type A (repo 連携 project)** であること（Type B/C は MOC + 単独ノートで十分）
- **vault SSoT の分析レポートが 3 件以上**存在し、raw 表 or 廃案ノートが発生していること（1-2 件なら MOC 内 1 行索引で十分）
- **repo 側に同種の正本ディレクトリが未整備** であること（例: make_article は repo `docs/x-operation/research/` を既に正本としており、vault に同階層を作る合理性なし → **不採用**）
- 横展開は **per-project 適格性レビュー** を経る（AI_adscrm をリファレンス実装とし、自動展開は禁止）
- 採用 project は台帳 `research/_summary.md` を必ず置く（雛形正本 = vault `templates/research-summary.md`）。新規調査ごとに台帳へ日付＋1行を追記（台帳に載らない調査ファイルは作らない）
- 台帳・命名・重複統合の運用正本 = skill `vault-research-ledger`（vault 側）。repo 側の隔離 = skill `research-isolation`

**リファレンス実装**: `02_Ai/AI_adscrm/AIcrm/research/{,_raw,_archive}/` (2026-05-27 構築・12 ファイル整理)

---

## A. 実行追跡（5）

| # | 種別 | 配置 |
|---|---|---|
| A-1 | 個別 task.md | repo `tasks/<slug>.md` |
| A-2 | phase tracker | repo `tasks/phase-tracker.md`（vault は 1 行サマリ） |
| A-3 | Session Handoff | repo `tasks/phase-tracker.md` 内 |
| A-4 | lessons learned | repo `tasks/lessons.md` |
| A-5 | TODO（task 内 sub） | task.md 内チェックリスト |

## B. メタ・思考ログ（4）

| # | 種別 | 配置 |
|---|---|---|
| B-1 | アーキ決定ログ | vault `wiki/meta/decisions.md`（cross・append-only） |
| B-2 | ミス・教訓 | vault `wiki/meta/mistakes.md`（cross・de-dup 上書き） |
| B-3 | implementation-notes | vault `02_Ai/<group>/<sub>-impl-notes.md`（**vault SSoT 例外**） |
| B-4 | 旧版 archive | repo `docs/archive/` / `tasks/archive/` |

## C. データ・スキーマ（5）

| # | 種別 | 配置 |
|---|---|---|
| C-1 | データソース台帳 | repo `docs/data-sources.md`（vault は住所 + 主要表） |
| C-2 | データ系譜 | repo `docs/data_lineage.yaml`（vault はカテゴリ別構造表） |
| C-3 | スキーマ辞書 | repo `docs/schema-*.md` |
| C-4 | 用語集 | repo `docs/glossary.md` |
| C-5 | 統計根拠（rationales） | repo `docs/rationales/*.md` |

## D. 入口・設定（5）

| # | 種別 | 配置 |
|---|---|---|
| D-1 | README.md | repo root |
| D-2 | CLAUDE.md（root） | repo root |
| D-3 | AGENTS.md | repo root |
| D-4 | SECURITY.md | repo root |
| D-5 | setup-runbook | repo `docs/setup-runbook.md` |

## E. 参考・取り込み（2）

| # | 種別 | 配置 |
|---|---|---|
| E-1 | 取り込みソース | vault `.raw/<topic>/`（cross・append-only） |
| E-3 | 監査レポート | K-4 で再配置（vault `wiki/meta/_audit/<group>.md`） |

*E-2 (refs) は L-2 へ統合。*

## F. 議事録 — 射程外

| # | 種別 | 配置 |
|---|---|---|
| F-1 / F-2 | 議事録（内部 / 外部） | **本ルール射程外**（vault `01_Biz/` で project 独立運用） |

## G. 制作物（3）

| # | 種別 | 配置 |
|---|---|---|
| G-1 | 記事原稿（make_article 系） | repo `make_article/output/` |
| G-2 | スクリーンショット・画像 | vault `attachments/` |
| G-3 | プロンプト | `<project>/prompts/<project>_INBOX.md`（投函＋`## 📒 記録`・全文保存・要約禁止。`spot/` 別ファイルと `_README` は廃止 2026-06-26・[[decisions]]） |

---

## H. 横串・レポート（5）

| # | 種別 | 配置 | 備考 |
|---|---|---|---|
| H-1 | 横串 MOC（group 統合） | vault `02_Ai/<group>/<group>_ope.md` | **`adscrm_cross.md` → `AI_adscrm_ope.md` リネーム要**（hook hardcode 影響範囲調査） |
| H-2 | エグゼクティブサマリ / 1-pager | vault `02_Ai/<group>/<group> 経営層 1-pager.md` | 図解付き（Mermaid / 表） |
| H-3 | レビュー記録（日付つきセカンドオピニオン） | **内容で分ける**（戦略レビュー→vault / 仕様レビュー→repo `<sub>/docs/reviews/`） | codex 推奨 C |
| H-4 | 定期レポート（spec-pulse 系） | repo `<sub>/metrics/spec-pulse/<date>.md` + vault サマリ | **spec-pulse-plan.md の出力先 hardcode 改修要** |
| H-5 | プロジェクト住所録（registry） | vault `wiki/meta/project-registry.md`（cross-project 統合） | 2026-05-25 移設: 旧 `02_Ai/AI_adscrm/project-registry.md` → `wiki/meta/` (vault 全体の横串インデックスとして B グループ meta と統合) |
| H-6 | issue tracking (bug / feature request / 第三者報告) | **GitHub Issues SoT** (`gh issue create -R <repo>`) + vault MOC `<sub>_ope.md` の `## 📋 Open Issues` セクションに自動ミラー | 2026-05-25 採用: `.github/ISSUE_TEMPLATE/bug-report.yml` 標準項目・SessionStart hook `sessionstart-github-issues.sh` + helper `sync-vault-summary.py issues` で `gh issue list` 上位 5 件を自動同期。vault は read-only mirror。境界: issue = 観測事象 / task.md = fix 作業 / impl-notes Open Questions = 実装中の設計疑問 |

## I. コード系（5・全 repo）

| # | 種別 | 配置 | 備考 |
|---|---|---|---|
| I-1 | 本番スクリプト | repo `scripts/<domain>/` ドメイン分割（`fetch/`, `aggregate/`, `sheet_sync/`, `guard/`, `etl/`） | codex 推奨 B |
| I-2 | 探索スクリプト（prefix `_`） | 現状維持（プロジェクトごと判断） | — |
| I-3 | ETL/分析パイプライン（番号 prefix） | repo `scripts/pipelines/<name>/step_NN.py` | — |
| I-4 | テスト | repo トップ `tests/` 集約 | prime_crm の近接配置も移動 |
| I-5 | プロジェクト hooks | repo `hooks/` | — |

## J. インフラ・設定（4・全 repo・全て現状維持）

| # | 種別 | 配置 |
|---|---|---|
| J-1 | 構造化設定（YAML/JSON） | repo `config/` トップ |
| J-2 | インフラ定義（Dockerfile / docker-compose.yml） | repo ルート |
| J-3 | 依存管理（requirements.txt） | repo ルート |
| J-4 | 環境変数テンプレ（.env.example） | repo ルート |

## K. テンプレ・特殊（4）

| # | 種別 | 配置 | 備考 |
|---|---|---|---|
| K-1 | プロジェクト固有テンプレ | repo `templates/` | — |
| K-2 | サブディレクトリ CLAUDE.md | **claude-mem 専用と割り切る**（人間ガイダンスは root CLAUDE.md のみ） | — |
| K-3 | プロジェクト内 wiki index (_index.md) | **廃止**（MOC で代替） | rules で project 内 wiki/ は推奨なし |
| K-4 | プロジェクト内 wiki audit (_audit.md) | **vault root `wiki/meta/_audit/<group>.md` に集約** | hook hardcode 修正要（weekly-vault-audit.sh L15 / sessionstart-vault-audit-warning.sh L20）。project 内 wiki/ ディレクトリ自体は廃止 |

## L. ライフサイクル（3）

| # | 種別 | 配置 | 備考 |
|---|---|---|---|
| L-1 | 1 回限り診断レポート | **0-6「分析」カテゴリに統合**（独立種別不要） | — |
| L-2 | 過去証跡 refs（ブレスト退避 / DONE 元プロンプト退避） | **すべて repo `<sub>/refs/` 集約** | vault `02_Ai/rohan/refs/` も repo へ移動 |
| L-3 | バックアップ / legacy（*.bak-*, .obsidian-done-legacy-*） | **`archive/` サブディレクトリ隔離保持**（例: `rohan/archive/`） | 即時削除は避け、必要時に復活可能 |

## M. データ・運用（6・2026-05-25 追記）

| # | 種別 | 配置 | 備考 |
|---|---|---|---|
| M-1 | secrets / 認証情報 | **placement 禁止** (全 repo) | `~/.zshrc` export + `${VAR}` 参照 (`rules/30-routing.md §シークレット` + `secret-management` skill 準拠) |
| M-2 | logs / 実行ログ | repo `logs/` (gitignore) | size 100MB 超は launchd で rotate |
| M-3 | データ raw | repo `data/raw/` (gitignore) | append-only / 取得元は `docs/data-sources.md` (C-1) |
| M-4 | データ processed | repo `data/processed/` (gitignore) | 再生成可能 / lineage は `docs/data_lineage.yaml` (C-2) |
| M-5 | キャッシュ | repo `.cache/` (gitignore) | 削除可・再生成前提・*.ok ファイル等の自動生成 marker 含む |
| M-6 | reports (定期出力) | repo `reports/<topic>-<date>.md` + vault サマリ | finding-sync skill 経由 (主に prime_crm)・finding ノート + key_findings.md + decision_log + executive_summary |

## N. ファイル命名規約 (type 別・2026-05-27 追加)

Obsidian / Anthropic 公式は vault 全体の単一命名規約を提供していない (2026-05-27 確認: `help.obsidian.md/files-and-folders/manage-vaults` 不在 / `code.claude.com/docs/en/memory` は CLAUDE.md / rules/<topic>.md の固有名指定のみ)。よって当環境固有規約として以下を定義 (kepano vault + Heppler academic vault + BIDS + Harvard HMS 横断引用ベース)。

| # | Type | 場所 | 命名形式 | 例 |
|---|---|---|---|---|
| N-1 | 分析レポート (research) | `02_Ai/<group>/<sub>/research/{,_raw,_archive}/` | `<project>-{research\|raw\|archive}-<topic>.md` | `prime-crm-research-hvs-key-findings.md` |
| N-2 | 横串知識 (concepts) | `wiki/concepts/` | `[Title].md` (kepano references 式・タイトルそのまま) | `Claude-Obsidian feedback loop.md` |
| N-3 | 外部ソース (sources) | `wiki/sources/` | `<slug>.md` (`_index.md` は obs-refs-index auto-gen) | `material-bank-20260424.md` |
| N-4 | meta 固定 | `wiki/meta/` | **固有名固定** (新規追加は decisions.md 起票が必要) | `decisions.md` / `mistakes.md` / `project-registry.md` |
| N-5 | 取り込み raw | `.raw/<topic>/` | `<topic>-YYYY-MM-DD.<ext>` (日付 prefix・append-only) | `grok-twittora-2026-05-12.jsonl` |
| N-6 | MOC | `02_Ai/<group>/` または `02_Ai/<group>/<sub>/` 親 | `<sub>_ope.md` (subproject) / `<group>_ope.md` (横串) | `AIcrm_ope.md` / `AI_adscrm_ope.md` |
| N-7 | implementation-notes | `02_Ai/<group>/` | `<sub>-impl-notes.md` (固有 suffix) | `AIcrm-impl-notes.md` |
| N-8 | claude-task (分析依頼) | `02_Ai/<group>/<sub>/tasks/` | `<YYYY-MM-DD>_<slug>.md` (日付 prefix・H-7 連動・一過性ファイル) | `2026-05-27_hvs-acquisition-1y.md` |

### 全体ルール

- **kepano「dates everywhere」原則は部分採用**: N-5 取り込み raw のみ日付 prefix 必須 (時系列ソート + append-only 識別に必要)。他 type は frontmatter `last_updated` で日付管理 (日付 prefix で wikilink ambiguity 増加を回避)
- **kebab-case 推奨** (英数字 + ハイフン)・N-2 / N-4 既存に spaces 許容 (kepano references 哲学準拠)
- **40-50 字以内 推奨** (Harvard HMS / Caltech / Michigan 横断指針)
- **wikilink ambiguity 防止**: 汎用名禁止 (`plan.md` / `measures.md` / `summary.md` / `index.md` 等) — rules/41 §② 継承
- **既存ファイル retro 適用は per-project 適格性レビュー** — 新規ファイルから本規約自動適用

### 根拠 (一次ソース・2026-05-27 調査)

- Obsidian 公式 `help.obsidian.md`: vault 命名規約ページ不在 (**公式推奨なし** を確認)
- Anthropic 公式 `code.claude.com/docs/en/memory`: CLAUDE.md / `.claude/rules/<topic>.md` の固有名指定のみ・vault 全般言及なし
- kepano `stephango.com/vault`: type 別命名 (Daily=`YYYY-MM-DD.md` / Atomic=`YYYY-MM-DD HHmm [title].md` / References=`[Title].md`) + 「Use YYYY-MM-DD dates everywhere」哲学
- Heppler academic vault `jasonheppler.org/2024/07/15`: per-project `Analysis/` subfolder (synthesis note 専用)
- Harvard HMS / Caltech / Michigan: 40-50 字制限・YYYY-MM-DD prefix・規約 README 明文化を推奨
- 外部 skill レジストリ調査 (`npx skills find`): 当環境型 vault 命名に直接適合する skill は未発見 (`nweii/file-naming` は取引文書用 / `dagster-io/rename-swarm` はコード識別子用)

## O. 仕事フォルダ横断・迷子防止（4・2026-07-10 構造監査で追加）

> 由来: 2026-07-10 仕事フォルダ4領域監査（12エージェント・提案9/保留45・Codexレビュー済）。監査台帳・復元ログ = `~/.claude/tasks/workfolder-structure-audit/`。領域版 = `vault:03_ClaudeEnv/placement-rules.md`（本節の要約+ポインタ・旧 Desktop 1枚版 `~/Desktop/_placement-rules.md` は不在のため 2026-07-16 張替）。vault サマリ = `wiki/meta/file-placement-rules.md` 同名節。

| # | 種別 | 配置 | 備考 |
|---|---|---|---|
| O-1 | Desktop 直下 | **一時作業面**。常駐可なのは「今使っている物」だけ | 3秒判定: ①帰属 project を言える→その project 配下（仕様書は `docs/`）②言えない＋今使っていない→ `~/Desktop/_desk-archive/YYYY-MM/` へ退避（削除しない）③ナレッジ→ vault（画像は `attachments/`・未分類ノートは `00_Inbox/`）。「名称未設定フォルダ」のまま放置禁止 |
| O-2 | prm / biz トップ階層 | **project dir ＋機能ファイルのみ**（`CLAUDE.md`＝ディレクトリスコープ設定・意図的 redirect md 等） | 旧版/退避は `<name>_STALE_YYYY-MM-DD` / `_<name>_BACKUP_YYYY-MM-DD` 命名（既存慣習の公式化）。`.bak` の平置き禁止→ `_desk-archive/YYYY-MM/`。repo 単位の統廃合はユーザー判断 |
| O-3 | vault root 直下 | **裸置き禁止**。allowlist = `MASA_HQ.md` のみ（decisions 2026-07-06） | 画像→ `attachments/` / 未分類ノート→ `00_Inbox/` / 知識→ `wiki/`。短縮 wikilink はファイル名で解決されるため `attachments/` への移動でリンクは壊れない（vault 内ファイル名一意が前提・移動前に find で確認） |
| O-4 | `~/.claude` root 直下 | **allowlist 外の新規平置き禁止**。allowlist: `CLAUDE.md` `AGENTS.md` `README.md` `plan.md` `GLOBAL_TASKS.md` `context-essentials.md`・settings 系 json・`setup.sh` `statusline.sh` | スクリプト→ `scripts/`（launchd/hook が絶対パス参照する場合は plist・settings 同時更新が必須＝例: totty2-weekly-line-collect.sh は CL-H1 保留）/ ドキュメント→ `docs/` / 完了 task→ `tasks/archive/` / runtime 領域（state/ projects/ sessions/ 等 gitignore 済）は不可侵 |

---

## 対象外節（2026-05-25 明示）

以下は本ルール (rules/42) の **enforcement 対象外**。Claude が新規ファイル配置を判断する際、これらは「rules/42 で配置先を判定しない・各 project の慣習に従う」:

- **gitignore 配下の自動生成物**: `*.pyc`, `__pycache__/`, `node_modules/`, ビルド成果物
- **FE+BE 構成プロジェクト** (rohan 等): `frontend/` `backend/` `routers/` 等の framework 規約配下は本ルール射程外。各 project の README/CLAUDE.md に従う
- **vault 全体の非連携領域**: `00_General/` `00_Inbox/` `01_Biz/` `Lifehack/` `Visual/` `tips/` `pf structure/` `projects/` `templates/` `attachments/` `02_Ai/` 直下の単独 .md (AIera.md 等)〔`03_ClaudeEnv/` は 2026-07-05 に連携ゾーン（環境ゾーン・Type A）へ昇格したため除外・`rules/41` 適用〕
- **議事録 (F グループ・既出)**: `01_Biz/` で project 独立運用

---

## 統計

- 既決定 8 / A 5 / B 4 / C 5 / D 5 / E 2 / F 0（射程外）/ G 3
- H 5 / I 5 / J 4 / K 4 / L 3 / M 6 (2026-05-25 追記) / **N 8 命名規約 (2026-05-27 追記・H-7 連動 N-8 追加)** / **O 4 仕事フォルダ横断 (2026-07-10 構造監査追加)**
- **合計 71 種**

カバー率（実プロジェクト監査・67 種時点の実測）: prime_ad 92 ファイル / prime_crm 57 ファイル / vault AI_adscrm 12 ファイル → **100%**（O 群 4 種は 2026-07-10 横断監査由来・上記実測の後に追加）

---

## 適用順序

1. ✅ **DONE (2026-06-13)** K-3+K-4 → AI_adscrm/wiki/ 解体完了 + hook hardcode 3 ファイル修正済み（weekly-vault-audit.sh: audit 出力を `wiki/meta/_audit/AI_adscrm.md` へ / weekly_spec_pulse.sh: 出力を `reports/` へ / sessionstart-vault-audit-warning.sh: 参照パス更新）。dated レポートは `reports/`、プロンプトは `prompts/` へ集約
2. ~~H-1 → adscrm_cross.md → AI_adscrm_ope.md リネーム~~ **supersede (2026-06-13)**: リネームせず実名 `adscrm_cross.md` を正とし rules/41 の例示を実名へ統一（横断 MOC = adscrm_cross.md）
3. ✅ **DONE (2026-06-13)** H-4 → weekly-update は **vault `reports/`** へ集約（repo 移動はせず・SessionStart 注入される人間用ダイジェストのため vault に残す）。spec-pulse 出力先 `reports/` へ改修済み
4. 既存 Red Flag（前棚卸し由来）: prime_ad/plan.md 1170 行肥大化 / prime_crm/plan.md 重複 / AIcrm_ope.md L93-204 / ~~aiads-ope-now-cat.sh hardcode バグ~~ **解決 (2026-06-23)**: 死にコード hook を削除（旧パス hardcode・settings 未登録・cross-ref ゼロ確認）
5. L-2 / L-3 → vault `02_Ai/rohan/` の refs と .bak / legacy 整理
6. **NEW (未)**: 定期実行 vault-prompt-runner（launchd + claude -p）の本番 activate（plist 納品済み・未ロード）+ S3 prime_ad/tasks/NOW.md への Phase 状態ビュー追加（prime_suite session で実施）
6. I-1 → prime_ad/scripts/ ドメイン分割（影響範囲: import パス）

詳細マッピング・差分案は `~/Desktop/prm/prime_suite-inventory/inventory/` を参照（worktree branch: `inventory/role-split-2026-05-24`）。

---

## 優先順位

`CLAUDE.md` > `rules/40-obsidian.md` > **本ルール (`rules/42`)** > `rules/41-vault-project-structure.md` > 各スキル SKILL.md。

本ルールは Type A の詳細制約（frontmatter / 命名禁止 / drift 防止）について `rules/41` を継承する。
