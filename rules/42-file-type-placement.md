---
paths:
  - "**/Obsidian Vault/**"
  - "**/wiki/**"
  - "~/.claude/**"
---

# ファイル種別 配置仕分け（プロジェクトルール v1・索引）

> **✅ Status: 稼働中**（`state/vault-cc-enabled` flag 在り〔2026-06-14〜〕＝ゲート対象 hook 4本が稼働。休眠は flag 削除で。2026-07-10 裁定は休眠意図だったが flag は残存し実際は稼働中だったため、2026-07-16 実態に合わせ Active に訂正）。
> **本ファイルは常時ロードされる薄い索引**。71 種の詳細表・備考・命名規約・根拠・適用順序・運用履歴は
> **`docs/file-placement-detail.md`（= `~/.claude/docs/file-placement-detail.md`）を必要時 Read**。
> （`30-routing.md` → `docs/routing-table.md` と同型の分離・2026-05-30 スリム化）

**確定日**: 2026-05-24 (Active 化: 2026-05-25 / O 群追加: 2026-07-10)
**位置づけ**: Claude ↔ Obsidian 連携プロジェクトでの **ファイル種別 71 種の配置 SSoT**
**関連 rules**: `40-obsidian.md`（vault 全体）/ `41-vault-project-structure.md`（Type A 詳細）/ `05-plan-task-md.md`
**vault サマリ版**: `~/Documents/Obsidian Vault/wiki/meta/file-placement-rules.md`
**詳細表 SSoT**: `~/.claude/docs/file-placement-detail.md`（全 71 種 + §0-6 補足 + N 命名規約 + O 仕事フォルダ横断・根拠 + 統計 + 適用順序 + 運用履歴）

---

## 基本原則

- **vault** = サマリ + 索引（人間レビュー動線） / **repo** = 全文 SSoT（コード・実データ・git 一体）
- **例外**: implementation-notes は vault SSoT（rules/41 §④）
- **secrets / 認証情報は placement 禁止**（M-1・全 repo）。`~/.zshrc` export + `${VAR}` 参照（`secret-management` skill）
- **命名**: 汎用名（`plan.md` / `measures.md` / `summary.md` / `index.md` 等）単体禁止・スコープ語前置（rules/41 §②）

## プロジェクトタイプ判定

| タイプ | 説明 | 例 |
|---|---|---|
| **A: repo 連携** | 分析・コード・データ=repo、vault=索引 | AI_adscrm |
| **B: vault-only** | repo なし・vault 内に全て | 知識ベース / PM ToDo |
| **C: 単発ノート** | 1 ファイル完結 | AIera.md 等 |

判定: ① 実コード or 実データを持つ → A / ② plan + 施策 + 分析 + 進捗の 2 種以上を継続運用 → B / それ以外 → C

---

## カテゴリ索引（各種の #・正確な配置・備考は `docs/file-placement-detail.md`）

| 群 | 種別数 | 配置の要点 |
|---|---|---|
| **0** 既決定 | 8 | 知識/draft→vault root直下 / 仕様・施策・計画・分析→repo 全文+vault 索引 / X ネタ`wiki/x-article-stock.md`・wiki 知識化`wiki/`→vault cross |
| **A** 実行追跡 | 5 | repo `tasks/`（`<slug>.md` / `phase-tracker.md`(Session Handoff含) / `lessons.md`） |
| **B** メタ・思考ログ | 4 | decisions/mistakes→vault `wiki/meta/`(cross) / impl-notes→**vault SSoT 例外** / 旧版→repo `archive/` |
| **C** データ・スキーマ | 5 | repo `docs/`（`data-sources.md` / `data_lineage.yaml` / `schema-*.md` / `glossary.md` / `rationales/`） |
| **D** 入口・設定 | 5 | repo root（README / CLAUDE / AGENTS / SECURITY）+ `docs/setup-runbook.md` |
| **E** 参考・取り込み | 2 | 取り込み→vault `.raw/<topic>/`(append-only) / 監査→vault `wiki/meta/_audit/<group>.md` |
| **F** 議事録 | 0 | **本ルール射程外**（vault `01_Biz/` で project 独立運用） |
| **G** 制作物 | 3 | 記事→repo `output/` / 画像→vault `attachments/` / プロンプト→`<project>/prompts/<project>_INBOX.md`（投函＋📒記録・全文保存・`spot/`/`_README` 廃止 2026-06-26） |
| **H** 横串・レポート | 5 | group MOC `<group>_ope.md` / 1-pager / レビュー記録 / spec-pulse / **registry=`wiki/meta/project-registry.md`** / issue=**GitHub Issues SoT** + MOC `## 📋 Open Issues` ミラー |
| **I** コード系 | 5 | repo `scripts/<domain>/` / `scripts/pipelines/` / `tests/`（top集約）/ `hooks/` |
| **J** インフラ・設定 | 4 | repo root/`config/`（YAML/JSON / Dockerfile / requirements.txt / .env.example） |
| **K** テンプレ・特殊 | 4 | repo `templates/` / project 内 wiki/（`_index.md` `_audit.md`）は**廃止**（MOC 代替） |
| **L** ライフサイクル | 3 | refs→repo `<sub>/refs/` 集約 / bak・legacy→`archive/` 隔離保持 |
| **M** データ・運用 | 6 | **secrets=禁止** / logs・data raw/processed・cache→repo gitignore / reports→repo+vault サマリ |
| **N** ファイル命名規約 | 8 | research / concepts / sources / meta / raw / MOC / impl-notes / claude-task の type 別命名形式 |
| **O** 仕事フォルダ横断・迷子防止 | 4 | Desktop=一時面（帰属不明→`_desk-archive/YYYY-MM/`）/ prm・biz トップ=project+機能ファイルのみ（旧版は STALE/BACKUP 命名）/ vault root=HQ以外裸置き禁止 / `~/.claude` root=allowlist外平置き禁止（2026-07-10 監査追加・領域版=`vault:03_ClaudeEnv/placement-rules.md`〔旧 Desktop 1枚版は不在・2026-07-16 張替〕） |

**合計 71 種**（カバー率 100% は 67 種時点の実測: prime_ad 92 + prime_crm 57 + vault AI_adscrm 12 ファイル。O 群は 2026-07-10 横断監査由来）。

---

## 対象外（rules/42 で配置判定しない・各 project の慣習に従う）

- **gitignore 配下の自動生成物**: `*.pyc` / `__pycache__/` / `node_modules/` / ビルド成果物
- **FE+BE 構成プロジェクト**（rohan 等）: `frontend/` `backend/` `routers/` 等の framework 規約配下 → 各 project の README/CLAUDE.md
- **vault 非連携領域**: `00_General/` `00_Inbox/` `01_Biz/` `Lifehack/` `Visual/` `tips/` `pf structure/` `projects/` `templates/` `attachments/` と `02_Ai/` 直下の単独 .md（AIera.md 等）〔`03_ClaudeEnv/` は 2026-07-05 に連携ゾーン（環境ゾーン・Type A）へ昇格したためリストから除外・`rules/41` 適用〕
- **議事録（F 群）**: `01_Biz/` で project 独立運用

---

## 優先順位

`CLAUDE.md` > `rules/40-obsidian.md` > **本ルール (`rules/42`)** > `rules/41-vault-project-structure.md` > 各スキル SKILL.md。

本ルールは Type A の詳細制約（frontmatter / 命名禁止 / drift 防止）について `rules/41` を継承する。
