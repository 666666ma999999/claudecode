# plan.md / task.md 運用ルール（要約）

全標準タスクの正本は **4 種**（2026-07-16 確定・一般名）: **plan**（戦略 SSoT・Why/成功基準）/ **spec**（定義 SSoT・数値/計算式/スキーマ）/ **architecture**（機能マップ・チャート＋I/O＋各機能の役割・新設）/ **task**（実行追跡）。本ルールは **plan/task** を扱う（spec/architecture の配置は `rules/42`・vault 表示は `rules/41`）。詳細: `~/.claude/docs/plan-task-md-detail.md`。

## 役割分担

- **plan.md**: feature 全体の Why/Who/成功基準/Phase 分解/影響範囲（feature 完了まで永続）
- **task.md**: Scope/Progress/Stuck/Session Handoff（数セッション、完了で archive）
- **task-light.md**: 1 セッション完結用の軽量版

重複禁止: 同じ情報を両方に書かない。task.md → plan.md へリンク（`plan.md#成功基準` 等）。

**task の 3 役（時間スパンで分ける・2026-07-16）**: `NOW.md`＝短期の優先順位（日々）／ `phase-tracker.md`＝長期の Phase 地図（週単位・節目）／ 個別 `tasks/*.md`＝単発の作業追跡。各 project が正本を CLAUDE.md 1 行で宣言（既存: prime_ad/crm＝NOW.md＋phase-tracker＋tasks/\*・他＝phase-tracker＋tasks/\*）。一本化しない（時間スパンが違う）。
**vault↔repo 配分（4 種共通・人間裁定=vault 正本／機械参照=repo 正本・2026-07-16 敵対レビュー2回確定）**: plan 戦略層=vault 候補／feature 実装計画=repo ・ spec=repo 実体＋vault 窓 ・ architecture 責務/境界=vault／モジュール/依存=repo ・ task=全 repo・vault 窓 ・ decisions/impl-notes=vault 正本。原則: 実体 SSoT=repo・vault=窓（コピー置かない・二重に書かない）。全文→ detail。

**vault との境界**: Obsidian 連携全条項 (`tasks/*.md` ↔ `wiki/meta/decisions.md` の SSoT 境界、wikilink 参照ルール、訂正プロトコル) は `rules/40-obsidian.md` 参照。重複定義は同ファイルに集約。

## トリガー

**plan.md 必須**: 新 feature / MVP / 複数 Phase / アーキ変更 / 3 ファイル以上変更
**task.md 必須**: 標準タスク全般 / `EnterPlanMode` を使う全タスク / stuck・blocker 発生時
**task-light.md でよい**: 1 ファイル数行 / 事実確認 / 既存 task.md の派生子
**plan.md 不要**: 既存 plan.md 範囲内の Slice / 設計判断なしバグ修正 / 小幅改修

## 配置

- `<project-root>/plan.md` — プロジェクト全体（1 プロジェクト 1 枚）
- `src/features/<name>/plan.md` — feature 単位（Feature Extension 構成）
- `tasks/<name>.md` — task.md（複数枚 OK）
- `tasks/phase-tracker.md` — Phase 横串
- `tasks/archive/` — 完了 task.md 退避先

## Phase 紐付け（要約）

命名・task.md 冒頭 2 行・plan.md 側アンカーの書式 → `docs/plan-task-md-detail.md`（§Phase 紐付け）

## テンプレ

`~/.claude/templates/{plan,task,task-light}.md`（選び方 → detail doc §テンプレート。迷ったら task-light）

## ワークフロー

- セッション開始: `ls plan.md tasks/*.md` → plan.md → 該当 task.md の Session Handoff / Stuck Context 確認
- 着手時: トリガー判定 → plan.md 作成/更新 → task.md 起こす → `## 成功基準` 定義 → `EnterPlanMode`
- セッション終了: Session Handoff 更新 / Progress Snapshot 最新化 / 未完なら Failures/Stuck 必須 / phase-tracker 反映
- **task 完了時（出口）**: NOW の Done/Superseded へ 1 行→**同セッション**で tasks/archive/ へ `git mv`・inbound 張替え・**機械参照（`task_md:` 等）の事前検索必須**・新サマリーファイル禁止。手順=`task-progress`§出口

## 禁止

- 3 ファイル以上変更で plan.md/task.md を作らない
- task.md 未作成で「memory で足りる」判断
- 成功基準なしで `EnterPlanMode`（hook 検知）
- plan.md「変更禁止ファイル」を触る（`plan-drift-warn.sh` PreToolUse auto-block）
- 完了 task.md をルート直下に残す

## Red Flags

4 パターン（tasks/ 空で複数変更・1 週間未更新 active・plan 外 feature 出現・Handoff 空疎）→ detail doc §Red Flags

## 関連スキル

`task-planner` / `task-progress` / `new-feature` / `plan-adversarial-review`

## 優先順位

`CLAUDE.md` > 本ルール > 他 rules/ > スキル。本ルールと他 rules/ 競合時は本ルール優先。
