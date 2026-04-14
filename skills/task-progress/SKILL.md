---
name: task-progress
description: task.md進捗管理スキル。セッション継続・要件変更追跡・stuck記録・ハンドオフを管理する。
triggers:
  - task進捗
  - stuck記録
  - セッション引き継ぎ
  - 要件変更追跡
  - task management
  - session handoff
  - progress tracking
not_for:
  - 通常のコード編集
  - git操作
  - テスト実行
allowed-tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Bash
---

# task-progress スキル

task.mdによるプロジェクト進捗管理。PM視点（要件追跡・スコープ管理・意思決定ログ）とEngineer視点（stuck記録・セッション引き継ぎ・技術的知見）を統合する。

## テンプレート

テンプレート選択基準:
- **軽量版** (`~/.claude/templates/task-light.md`): 単発タスク、1セッションで完了見込み、PM管理不要
- **フル版** (`~/.claude/templates/task.md`): 複数セッション、要件変更追跡、PM視点管理が必要
- 迷ったら軽量版で開始し、必要に応じてフル版に昇格する

## Read Protocol（セッション開始時）

### Step 1: task.md検出
```bash
# プロジェクトのtasksディレクトリを確認
ls tasks/*.md 2>/dev/null
# またはプロジェクトルートを確認
ls task.md 2>/dev/null
# 後方互換: 旧パスも確認
ls .claude/workspace/task.md 2>/dev/null
```

### Step 2: 読み順（優先度順）
1. **Metadata** → Status確認。done/pausedなら理由を確認
2. **Session Handoff** → 前セッションの引き継ぎ事項
3. **Current State** → 現在の仮説とconfidence
4. **Progress Snapshot** → Blocked/Next を確認
5. **Failures / Stuck Context** → 過去の失敗を把握（同じ轍を踏まない）
6. **Current Agreed Scope** → Must/Descoped境界を確認
7. **Decision Log** → 過去の判断理由を把握

### Step 3: 状況報告
読み込み後、ユーザーに以下を簡潔に報告:
- 現在のStatus
- 前回の中断地点
- 推奨する次のアクション

## Write Protocol（いつ何を更新するか）

### 常に更新
- **最終更新**: 変更のたびに日時を更新

### Status変更時
| 遷移 | トリガー | 更新セクション |
|------|---------|--------------|
| → active | 作業開始 | Metadata, Current State |
| → blocked | 外部依存待ち | Metadata, Dependencies, Progress Snapshot |
| → stuck | 試行失敗3回 or 30分停滞 | Metadata, Failures/Stuck Context, Current State |
| → paused | ユーザー指示 or 優先度変更 | Metadata, Session Handoff |
| → done | 成功基準達成 | Metadata, Progress Snapshot, Session Handoff |

### 試行失敗時
1. **Failures / Stuck Context** テーブルに行追加
2. **Category** を19カテゴリから選択
3. **Current State.Hypothesis** を更新
4. **Current State.Confidence** を下方修正

### 要件変更検知時
1. **Requirements History** に変更を記録
2. **Current Agreed Scope** を更新（Must/Nice-to-have/Descoped）
3. **Decision Log** に変更判断を記録
4. ユーザーに変更影響を報告

### 意思決定時
1. **Decision Log** に記録（選択肢・理由・却下理由すべて）
2. 重要な判断は **Iteration History** にも反映

### セッション終了前（必須）
1. **Session Handoff** の4セクションを全て更新:
   - Start Here: 次セッションの再開ポイント
   - Avoid Repeating: 試して駄目だったアプローチ
   - Key Evidence: 重要なログ/エラー/確認済み事実
   - If Still Failing: 代替案
2. **Current State** を最新化
3. **Progress Snapshot** を最新化
4. **Status** を適切に設定（active/paused/stuck）

### 終了ガード（必須）
- Status が done 以外で Failures/Stuck Context が空の場合、stuck理由の記録を強制する
- 「なぜ完了できなかったか」を必ず記録してからセッション終了すること

## Stuck Reason 分類ガイド

### 技術系（12カテゴリ）

| Category | 使用場面 | 例 |
|----------|---------|-----|
| tool_limitation | ツールの機能制限 | Playwright MCPでfile://が使えない |
| environment_constraint | 環境固有の制約 | M1 Macでx86バイナリが動かない |
| dependency_failure | 依存パッケージの問題 | npm install失敗、バージョン非互換 |
| config_issue | 設定ファイルの問題 | 環境変数未設定、ポート競合 |
| api_auth | API認証の問題 | トークン期限切れ、権限不足 |
| api_behavior | APIの予期しない動作 | レスポンス形式変更、undocumented制限 |
| service_unavailable | 外部サービス停止 | GitHub API障害、CMS応答なし |
| code_bug | コード自体のバグ | ロジックエラー、型不一致 |
| integration_mismatch | コンポーネント間の不整合 | FE/BE間のスキーマ不一致 |
| test_instability | テストの不安定性 | flaky test、タイミング依存 |
| insufficient_observability | デバッグ情報不足 | ログなし、エラーが握りつぶされている |
| unknown | 原因不明 | 再現性なし、情報不足 |

### PM系（7カテゴリ）

| Category | 使用場面 | 例 |
|----------|---------|-----|
| requirements_unclear | 要件が曖昧 | 「いい感じに」「適切に」等の指示 |
| scope_change | スコープ変更 | 実装中に要件追加/変更 |
| priority_shift | 優先度変更 | 緊急タスク割り込み |
| approval_pending | 承認待ち | デザイン承認待ち、レビュー待ち |
| assumption_unverified | 前提未検証 | 「このAPIがある前提」が未確認 |
| user_feedback_pending | ユーザー確認待ち | 仕様確認の回答待ち |
| dependency_blocked | 他タスク/チーム依存 | 先行タスク未完了 |

## 運用ルール

### 必須
- **重複行禁止**: 同じ内容を複数セクションに書かない。参照で済ませる
- **Current Hypothesis 常に最新**: 仮説が変わったら即更新
- **Confidence 正直に**: 根拠なくhighにしない
- **Failures記録は省略しない**: 失敗こそ最も価値ある情報

### 推奨
- What Was Doneテーブルは時系列順（新しい順）
- Decision Logは判断の大きさに関わらず記録
- Session Handoffは「未来の自分へのメモ」として書く

### 禁止
- task.mdにコード全文を貼り付ける（パス参照のみ）
- 成功した試行のみ記録する（失敗も必ず記録）
- Statusをdoneにしたまま作業を続ける

## task.mdインスタンス配置

- プロジェクト内: `tasks/` ディレクトリに配置（例: `tasks/feature-auth.md`）
- 単発タスク: プロジェクトルートの `task.md`
- テンプレート: `~/.claude/templates/task.md` からコピーして使用

## Use Cases

### A. セッション継続系（Engineer寄り）
- **UC1**: ツール制限/環境制約の記録と回避策引き継ぎ → Failures/Stuck Context + Open Workarounds
- **UC2**: 繰り返す外部サービス障害の知見蓄積 → Failures/Stuck Context (service_unavailable)
- **UC3**: SubAgent委託の中断復帰 → Session Handoff + Current State

### B. プロジェクト管理系（PM寄り）
- **UC4**: 要件ドリフト追跡 → Requirements History + Current Agreed Scope
- **UC5**: スコープ管理 → Current Agreed Scope (Must/Nice-to-have/Descoped)
- **UC6**: 意思決定ログ → Decision Log
- **UC7**: ビジネスコンテキスト保持 → Business Context
- **UC8**: イテレーション追跡 → Iteration History
- **UC9**: 進捗の可視化 → Progress Snapshot + What Was Done
- **UC10**: フィードバック蓄積 → Feedback and Preferences
