# plan.md / task.md 運用ルール（要約）

全標準タスクは **plan.md（設計 SSoT）+ task.md（実行追跡）の 2 層構造**。詳細: `~/.claude/docs/plan-task-md-detail.md`。

## 役割分担

- **plan.md**: feature 全体の Why/Who/成功基準/Phase 分解/影響範囲（feature 完了まで永続）
- **task.md**: Scope/Progress/Stuck/Session Handoff（数セッション、完了で archive）
- **task-light.md**: 1 セッション完結用の軽量版

重複禁止: 同じ情報を両方に書かない。task.md → plan.md へリンク（`plan.md#成功基準` 等）。

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

命名: `p<N>-<slug>.md` / `sprint<N>-<slug>.md` / `bl-<N>-<slug>.md` / `<slug>.md`
task.md 冒頭 2 行: `**Phase:** [Phase N](../plan.md#phase-<N>)` / `**Tracker:** [phase-tracker §Phase N](./phase-tracker.md#phase-<N>)`
plan.md 側: 各 Phase 見出し直後に `<a id="phase-<N>"></a>`

## テンプレ

- `~/.claude/templates/plan.md` / `task.md` / `task-light.md`
- 迷ったら `task-light.md`、Decision Log が必要になったら `task.md` 昇格

## ワークフロー

- セッション開始: `ls plan.md tasks/*.md` → plan.md → 該当 task.md の Session Handoff / Stuck Context 確認
- 着手時: トリガー判定 → plan.md 作成/更新 → task.md 起こす → `## 成功基準` 定義 → `EnterPlanMode`
- セッション終了: Session Handoff 更新 / Progress Snapshot 最新化 / 未完なら Failures/Stuck 必須 / phase-tracker 反映

## 禁止

- 3 ファイル以上変更で plan.md/task.md を作らない
- task.md 未作成で「memory で足りる」判断
- 成功基準なしで `EnterPlanMode`（hook 検知）
- plan.md「変更禁止ファイル」を触る（`plan-drift-warn.sh` PreToolUse auto-block）
- 完了 task.md をルート直下に残す

## Red Flags

- `tasks/` 空なのに複数ファイル変更進行中
- task.md 1 週間以上 active のまま未更新
- plan.md 未記載の「新 feature」が突然コードに出現
- Session Handoff が「作業継続中」のみで Start Here / Avoid Repeating / Key Evidence 空

## 関連スキル

`task-planner` / `task-progress` / `new-feature` / `plan-adversarial-review`

## 優先順位

`CLAUDE.md` > 本ルール > 他 rules/ > スキル。本ルールと他 rules/ 競合時は本ルール優先。
