---
name: security-twin-audit
description: |
  Security Twin Agents（Black Hacker + White Hacker）によるセキュリティ監査を実行する。
  Agent Teams を使用して攻撃者視点と防御者視点で並行分析し、統合レポートを生成する。
  キーワード: セキュリティ監査, security audit, 脆弱性診断, Red Team, Blue Team, Twin Agents
  NOT for: 単純なコード修正、テスト実行、通常のコードレビュー
allowed-tools: "Read Glob Grep Bash Task TaskCreate TaskUpdate TaskList TeamCreate SendMessage"
---

# Security Twin Audit スキル

## 概要
Black Hacker（Red Team）と White Hacker（Blue Team）の双子エージェントによる
セキュリティ監査を Agent Teams で実行する。

## 実行手順

### Step 1: 対象確認

```
対象ディレクトリ/ファイルをユーザーに確認:
- 全体監査: プロジェクトルート
- 差分監査: 特定のPR/ブランチのdiff
- スポット監査: 特定モジュール/ファイル
```

### Step 2: Agent Team 起動

```
1. TeamCreate("security-audit-{project名}")

2. タスク作成（依存関係付き）:

   Task 1: [Black] "偵察: エントリポイント・認証フロー・データフロー分析"
   Task 2: [White] "防御評価: 既存セキュリティ機構の棚卸し"
   Task 3: [Black] "OWASP Top 10 脆弱性スキャン" (blocked by Task 1)
   Task 4: [White] "脆弱性対策の多層防御設計" (blocked by Task 3)
   Task 5: [Black] "対策バイパス検証" (blocked by Task 4)
   Task 6: [Lead]  "最終レポート統合" (blocked by Task 5)

3. エージェント起動:
   - Task tool で black-hacker agent を team_name 付きで起動
   - Task tool で white-hacker agent を team_name 付きで起動
```

### Step 3: 議論フェーズ

```
Black → White: 脆弱性発見を共有
White → Black: 対策案を共有
Black → White: バイパス可能性を指摘
White: 対策を修正
→ 収束するまで繰り返し
```

### Step 4: レポート統合

Lead が以下のレポートを生成:

```markdown
# Security Audit Report - {project名}
## Date: {実行日}
## Scope: {対象範囲}

### Executive Summary
- 発見脆弱性数: CRITICAL(x) / HIGH(x) / MEDIUM(x) / LOW(x)
- 対策提案数: x件
- 未解決リスク: x件

### 脆弱性一覧（深刻度順）
| # | 深刻度 | カテゴリ | 概要 | 対策状況 |
|---|--------|---------|------|---------|
| 1 | CRITICAL | A03:Injection | ... | 対策案あり |

### 対策提案一覧（優先度順）
| # | 優先度 | 対象脆弱性 | 対策概要 | 修正ファイル |
|---|--------|-----------|---------|------------|
| 1 | P0 | #1 SQLi | パラメータ化 | api/db.py |

### 詳細
（各脆弱性と対策の詳細）

### 残存リスク
（対策後も残るリスクとその受容判断）
```

### Step 5: 保存

レポートを以下に保存:
- `.claude/workspace/security-audit-{date}.md`

## Agent Teams なしでの実行（簡易版）

Teams が利用できない場合、SubAgent で順次実行:

```
1. Black Hacker SubAgent → 脆弱性レポート取得
2. White Hacker SubAgent → 脆弱性レポートを渡して対策取得
3. Lead が統合
```

## 対象プロジェクトの自動判定

以下のファイルでプロジェクト種別を判定:
- `requirements.txt` / `pyproject.toml` → Python
- `package.json` → Node.js
- `go.mod` → Go
- `Cargo.toml` → Rust
- `pom.xml` / `build.gradle` → Java

種別に応じて重点チェック項目を調整する。
