---
name: task-progress
description: task.md進捗管理スキル。セッション継続・stuck記録・ハンドオフを管理する。
triggers:
  - task進捗
  - stuck記録
  - セッション引き継ぎ
  - progress tracking
  - session handoff
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

task.mdによるプロジェクト進捗管理。stuck記録とセッション引き継ぎに集中する軽量スキル。

## テンプレート

`~/.claude/templates/task.md` を使用。

## Read Protocol（セッション開始時）

### Step 1: task.md検出
```bash
ls tasks/*.md 2>/dev/null
ls task.md 2>/dev/null
```

### Step 2: 読み込み & 報告
ファイルを読み込み、ユーザーに以下を簡潔に報告:
- 現在のStatus
- 前回の中断地点（Session Handoff → Start Here）
- 推奨する次のアクション（Progress → Next）

## Write Protocol（いつ更新するか）

### トリガー1: セッション終了前（必須）

1. **Progress** を最新化（Done / In Progress / Next）
2. **Session Handoff** の4項目を全て更新:
   - Start Here: 次セッションの再開ポイント
   - Avoid Repeating: 試して駄目だったアプローチ
   - Key Evidence: 重要なログ/エラー/確認済み事実
   - If Still Failing: 代替案
3. **Status** を適切に設定
4. **Updated** 日付を更新

### トリガー2: stuck発生時

1. **Stuck Log** にエントリ追加（日付 + 問題 + 解決策）
2. **Status** を `stuck` に変更
3. **Updated** 日付を更新

## 運用ルール

### 必須
- **Failures記録は省略しない**: 失敗こそ最も価値ある情報
- **Session Handoffは「未来の自分へのメモ」として書く**

### 禁止
- task.mdにコード全文を貼り付ける（パス参照のみ）
- 成功した試行のみ記録する（失敗も必ず記録）
- Statusをdoneにしたまま作業を続ける

## task.mdインスタンス配置

- プロジェクト内: `tasks/` ディレクトリに配置（例: `tasks/feature-auth.md`）
- 単発タスク: プロジェクトルートの `task.md`
- テンプレート: `~/.claude/templates/task.md` からコピーして使用
