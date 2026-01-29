# タスク管理システム

## 概要

セッション間の作業引継ぎを効率化するためのtask.mdベースの管理システム。

## コマンド一覧

| コマンド | 用途 | タイミング |
|---------|------|-----------|
| `/launch-task` | 新規タスク開始・task.md生成 | Issue発行後 |
| `/onboard` | 中断した作業の復帰 | セッション開始時 |
| `/update-task` | task.mdの状態更新 | 作業の節目・中断前 |
| `/update-task --checkpoint` | 中断準備（状態保存） | 作業中断時 |
| `/update-task --complete` | タスク完了処理 | 全作業完了時 |
| `/review` | Codexコードレビュー | 実装完了後・commit前 |
| `/verify-step` | STEP完了確認 | 各STEP実行後 |

## ディレクトリ構成

```
project-root/
└── .claude/
    └── workspace/
        └── task.md        # 現在のタスク状態

~/.claude/
├── commands/              # カスタムコマンド定義
│   ├── launch-task.md
│   ├── onboard.md
│   ├── update-task.md
│   └── review.md          # Codexレビュー
├── hooks/                 # 自動化スクリプト
│   ├── file-protection.sh
│   ├── security-scan.sh
│   └── auto-format.sh
└── templates/
    └── task.md            # task.mdテンプレート
```

## 推奨ワークフロー

### 新規タスク開始
```
1. Issue発行
2. /launch-task [Issue URL]
3. Planモードで設計
4. 実装開始
```

### 作業中断
```
1. /update-task --checkpoint
2. セッション終了
```

### 作業再開
```
1. /onboard
2. 状態確認
3. 作業継続
```

### タスク完了
```
1. /update-task --complete
2. スキル横展開チェック（自動）
3. Issue Close
```

## task.mdの必須セクション

| セクション | 用途 |
|-----------|------|
| メタ情報 | Issue、ステータス、日時 |
| 成功基準 | 完了条件のチェックリスト |
| 実装計画 | Phase分割された作業項目 |
| 中断時の状態 | 次のアクション、未解決問題 |
| 学んだこと | 完了時の知見記録 |
