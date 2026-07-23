# Task: [タスク名]

## Metadata

| 項目 | 値 |
|------|-----|
| Status | active / blocked / stuck / paused / done |
| Issue | [#XXX](URL) |
| 開始日時 | YYYY-MM-DD HH:MM |
| 最終更新 | YYYY-MM-DD HH:MM |
| 担当 | [担当者/エージェント] |

## Goal

[1文でタスクの目的を記述]

## 成功基準

- [ ] [観測可能な完了条件。例: `curl localhost:8000/api/x` が HTTP 200 を返し、レスポンス件数が10件になる]
- [ ] [検証コマンドと期待結果を数値または PASS/FAIL で記載]

## Business Context

| 項目 | 値 |
|------|-----|
| 締切 | YYYY-MM-DD or なし |
| 優先度 | P0(緊急) / P1(高) / P2(中) / P3(低) |
| ステークホルダー | [誰が結果を気にするか] |

## Current Agreed Scope

### Must（合意済み必須）
- [ ] 項目1
- [ ] 項目2

### Nice-to-have（余裕があれば）
- [ ] 項目1

### Descoped（明示的に除外）
- 項目1（除外理由: ...）

## Requirements History

| 日時 | 変更内容 | 変更理由 | 影響 |
|------|---------|---------|------|
| YYYY-MM-DD | 初期要件 | — | — |

## Current State

| 項目 | 値 |
|------|-----|
| Summary | [現在の状況を1-2文で] |
| Focus | [今取り組んでいること] |
| Hypothesis | [現在の仮説/アプローチ] |
| Confidence | high / medium / low |

## Progress Snapshot

### Done
- [x] 完了項目

### In Progress
- [ ] 作業中項目

### Blocked
- [ ] ブロック項目（理由: ...）

### Next
- [ ] 次の作業

### Batch N（fast_verify: `<検証コマンド>`）
- [ ] T1: [動詞 + 対象] | `[ファイルパス]` | owner: [担当] | 依存: [なし/T#]
- [ ] T2: [動詞 + 対象] | `[ファイルパス]` | owner: [担当] | 依存: [なし/T#]
- [ ] T3: [動詞 + 対象] | `[ファイルパス]` | owner: [担当] | 依存: [なし/T#]

## What Was Done

| # | 日時 | 内容 | 結果 | ファイル |
|---|------|------|------|---------|
| 1 | YYYY-MM-DD HH:MM | 作業内容 | 成功/失敗/部分的 | `path/to/file` |

## Decision Log

> 実装中に「仕様書・plan.md に書かれていない判断 / 逸脱 / 解釈 / 要確認」が出たら 1 行記録する（implementation-notes 運用・Thariq Shihipar 提唱）。仕様通りの実装は記録不要。
> ※ vault 連携プロジェクト (02_Ai/ 配下) では vault の `<project>-impl-notes.md` が正本。本セクションは非 vault プロジェクト用（rules/41 参照）。

| # | 日時 | 判断 | 選択肢 | 選んだ理由 | 却下理由 | 仕様差分 |
|---|------|------|--------|-----------|---------|---------|
| 1 | YYYY-MM-DD | 判断内容 | A vs B | Aを選択: ...（参照: plan.md#成功基準） | Bは..のため不適 | deviation |

**仕様差分の値**（implementation-notes の 4 観点に対応）:
- `on-spec` — 仕様通り（記録任意）
- `interpreted` — 仕様が曖昧 → 実装側で解釈して進めた
- `deviation` — 仕様から意図的に逸脱した（理由を「選んだ理由」に明記）
- `open-question` — 暫定判断・ユーザーの確認/修正が必要（未解決）

> トレードオフは「選択肢 / 却下理由」列で表現。暫定回避は `## Open Workarounds`、失敗は `## Failures / Stuck Context` が正本（重複記載しない）。

## Iteration History

| Version | 日時 | 概要 | 却下/変更理由 |
|---------|------|------|-------------|
| V1 | YYYY-MM-DD | 初期アプローチ | — |

## Failures / Stuck Context

| # | 日時 | Category | 内容 | 解決策/回避策 | 解決? |
|---|------|----------|------|-------------|------|
| 1 | YYYY-MM-DD | [category] | 詳細 | 対応内容 | yes/no |

### Stuck Reason Categories

**技術系**: tool_limitation, environment_constraint, dependency_failure, config_issue, api_auth, api_behavior, service_unavailable, code_bug, integration_mismatch, test_instability, insufficient_observability, unknown

**PM系**: requirements_unclear, scope_change, priority_shift, approval_pending, assumption_unverified, user_feedback_pending, dependency_blocked

## Open Workarounds

| # | 対象 | 回避策 | 恒久対応予定 |
|---|------|--------|------------|
| 1 | 問題 | 暫定対応 | TODO/不要 |

## Risks and Assumptions

| # | 種別 | 内容 | 影響度 | 対応策 |
|---|------|------|--------|--------|
| 1 | Risk/Assumption | 詳細 | high/medium/low | 軽減策 |

## Dependencies

| # | 依存先 | 種別 | 状態 | 影響 |
|---|--------|------|------|------|
| 1 | [サービス/チーム/タスク] | 技術/承認/外部 | 解決済/待ち | ブロック時の影響 |

## Feedback and Preferences

| # | 日時 | フィードバック | 対応 |
|---|------|--------------|------|
| 1 | YYYY-MM-DD | ユーザーからの指摘 | 反映内容 |

## Next Actions

1. [ ] アクション1（優先度: 高）
2. [ ] アクション2（優先度: 中）

## Session Handoff

### Start Here
[次セッションで最初に読むべき情報。現在地と次のアクション]

### Avoid Repeating
[既に試して失敗したアプローチ。同じ轍を踏まないために]

### Key Evidence
[重要なログ出力、エラーメッセージ、確認済み事実]

### If Still Failing
[現在のアプローチが行き詰まった場合の代替案]
