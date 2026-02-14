---
name: process-state-management
description: 複数ステップのプロセスを管理し、ログ記録・中断理由追跡・途中再開を可能にするパターン集。コンテキスト設計原則、エラー収集パターンも含む。新規プロジェクトでマルチステップ処理を実装する際に使用。
allowed-tools: "Read Glob Grep"
metadata:
  author: masaaki-nagasawa
  version: 1.0.0
---

# Process State Management Skill

## 使用タイミング

以下の場面でこのスキルを発動:
- 複数ステップの処理フローを実装する
- プロセスの中断・再開機能が必要
- 処理ログを記録したい
- エラー発生時の原因追跡が必要
- 「ステップ管理」「プロセス状態」「再開機能」などのキーワードが出た
- 文字列置換でデータ結合が失敗する（→ `references/state-design.md`）
- 複数操作のエラーをまとめて報告したい（→ `references/error-handling.md`）
- Step間でデータを渡す際にパースエラーが発生（→ `references/state-design.md`）

## アーキテクチャ概要

```
┌─────────────────────────────────────────────────────────┐
│                   ProcessRecord                          │
├─────────────────────────────────────────────────────────┤
│ record_id: string          # 一意識別子                  │
│ created_at: datetime       # 作成日時                    │
│ updated_at: datetime       # 更新日時                    │
│ status: enum               # overall/running/completed/  │
│                            #   error/interrupted         │
│ current_step: number       # 現在のステップ番号          │
│ steps: StepProgress[]      # 各ステップの状態            │
│ context: object            # プロセス固有のコンテキスト   │
│ logs: LogEntry[]           # 詳細ログ                    │
│ interrupt_reason: string   # 中断理由（あれば）          │
├─────────────────────────────────────────────────────────┤
│ StepProgress: step, name, status(pending/running/       │
│   success/error/skipped), started_at, completed_at,     │
│   result, error(ErrorInfo), retry_count                  │
├─────────────────────────────────────────────────────────┤
│ LogEntry: timestamp, level(debug/info/warn/error),      │
│   step, message, data                                    │
└─────────────────────────────────────────────────────────┘
```

## 核心原則

### 1. 構造化データ優先
Step間のデータ受け渡しはテキスト変換せず構造化データのまま渡す。テキスト版は表示用フォールバックとして残す。
→ 詳細: `references/state-design.md`

### 2. セッション永続化
複数STEPで使う共通データはグローバル変数 + セッション保存 + 復元の3点セットで管理する。
→ 詳細: `references/state-design.md`

### 3. エラー分類と再開可能性
エラーは種類（validation/timeout/network/auth/system）で分類し、再開可能性を判定する。
→ 詳細: `references/error-handling.md`

### 4. エラー収集パターン
独立した複数操作はFail-Fastせず全エラーを収集してまとめて報告する。
→ 詳細: `references/error-handling.md`

## クイックスタート

### 新規プロジェクトへの適用手順

1. **ステップ定義の作成**
```python
STEP_DEFINITIONS = {
    1: {"name": "初期化", "timeout": 30, "retryable": True},
    2: {"name": "データ取得", "timeout": 60, "retryable": True},
    3: {"name": "処理実行", "timeout": 120, "retryable": False},
    4: {"name": "結果保存", "timeout": 30, "retryable": True},
}
```

2. **ProcessRecordモデルのカスタマイズ**
   - `context` フィールドにプロジェクト固有のデータ構造を定義

3. **APIエンドポイントの追加**
   - `/api/process/create`, `/{record_id}`, `/{record_id}/step`, `/{record_id}/log`, `/incomplete/list`

4. **FEヘルパー関数の追加**
   - `createProcess()`, `updateStepStatus()`, `addLog()`, `resumeProcess()`

5. **再開バナーUIの追加**

## 実装パターン（参照）

| パターン | 参照先 |
|---------|--------|
| バックエンド（Python/FastAPI） | `references/backend-pattern.md` |
| フロントエンド（JavaScript） | `references/frontend-pattern.md` |
| ログ記録 | `references/logging-pattern.md` |
| エラーハンドリング・中断理由 | `references/error-handling.md` |
| コンテキスト設計・状態管理 | `references/state-design.md` |
| エラー復旧・再開パターン | `references/error-resume-pattern.md` |
| 実装例（登録フロー） | `references/implementation-example.md` |

## 実装上の注意

### モデル重複禁止
`StepProgress` と `StepStatus` は `backend/utils/models.py` に統一定義済み。
各routerでは `from utils.models import StepProgress, StepStatus` でインポートすること。ローカル再定義は禁止。

### セッション復元時のUI更新
グローバル変数を復元したら、対応するdisplay関数を必ず呼ぶ（変数代入だけではUIに反映されない）。
→ 詳細: `references/state-design.md`

### 派生フィールドの保存
マスターデータから導出される値はセッション保存時に含める。復元時の読み込みタイミング依存を排除する。
→ 詳細: `references/state-design.md`

## ベストプラクティス

1. **ステップの粒度**: 1ステップ = 1つの論理的な処理単位。再開時に途中から実行できる粒度にする
2. **コンテキストの保存**: 各ステップ完了時に中間結果を保存。再開時に必要な情報が復元できること
3. **ログの活用**: 重要な判断点でログを記録。エラー時は詳細情報を含める。個人情報はマスキング
4. **エラーハンドリング**: リトライ可能なエラーとそうでないものを区別。エラー情報には対処法を含める

## 判定ツリー

```
マルチステップ処理を実装？
├─ YES → このスキルを適用
│   ├─ 中断・再開が必要？ → references/error-resume-pattern.md
│   ├─ Step間データ受渡し？ → references/state-design.md
│   ├─ バッチエラー処理？ → references/error-handling.md
│   ├─ ログ設計？ → references/logging-pattern.md
│   └─ 具体的な実装例？ → references/implementation-example.md
└─ NO → 別のスキルを検索
```
