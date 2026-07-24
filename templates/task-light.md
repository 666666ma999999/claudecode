# Task: [タスク名]

## Metadata
| 項目 | 値 |
|------|-----|
| Status | active / blocked / stuck / paused / done |
| 開始日時 | YYYY-MM-DD HH:MM |
| 最終更新 | YYYY-MM-DD HH:MM |

## Goal
[1文でタスクの目的を記述]

## 成功基準
- [ ] [観測可能な完了条件。例: `curl localhost:8000/api/x` が HTTP 200 を返し、レスポンス件数が10件になる]
- [ ] [検証コマンドと期待結果を数値または PASS/FAIL で記載]

## Progress
### Batch N（fast_verify: `<検証コマンド>`）
- [ ] T1: [動詞 + 対象] | `[ファイルパス]` | owner: [担当] | 依存: [なし/T#]
- [ ] T2: [動詞 + 対象] | `[ファイルパス]` | owner: [担当] | 依存: [なし/T#]
- [ ] T3: [動詞 + 対象] | `[ファイルパス]` | owner: [担当] | 依存: [なし/T#]

## Decision Log
仕様書・plan.md に無い判断 / 逸脱 / 解釈 / 要確認が出たら記録（implementation-notes 運用）。仕様通りなら記録不要。

| 日時 | 判断 | 仕様差分 |
|------|------|---------|
| YYYY-MM-DD | 判断内容 | interpreted / deviation / open-question |

> `deviation` か `open-question` が出たら task.md（フル版）へ昇格する。

## Failures / Stuck Context
| # | Category | 内容 | 解決策 | 解決? |
|---|----------|------|--------|------|

## Session Handoff
### Start Here
[次セッションの再開ポイント]
### Avoid Repeating
[試して失敗したアプローチ]
### Key Evidence
[重要なログ/エラー/確認済み事実]
