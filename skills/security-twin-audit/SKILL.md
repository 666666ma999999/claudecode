---
name: security-twin-audit
description: |
  Security Twin Agents（Black Hacker + White Hacker）によるセキュリティ監査を実行する。
  Agent Teams を使用して攻撃者視点と防御者視点で並行分析し、統合レポートを生成する。
  キーワード: セキュリティ監査, security audit, 脆弱性診断, Red Team, Blue Team, Twin Agents,
  セキュリティ差分監査, PRセキュリティレビュー, 差分限定監査（旧 /review-security を吸収 2026-07-16・
  差分限定は「対象=git diff の変更範囲」と指定して本スキルを使う）
  NOT for: 単純なコード修正、テスト実行、通常のコードレビュー
allowed-tools: [Read, Write, Glob, Grep, Bash, Agent, SendMessage, AskUserQuestion]
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

### Step 2: Twin Agents 起動・順序制御

```
1. Agent tool で次の 2 体を name 付きで並行起動:
   - subagent_type: black-hacker, name: black-hacker
   - subagent_type: white-hacker, name: white-hacker

2. SendMessage で名前を指定し、フェーズ間の成果物を渡して順序を保証:
   - Phase 1: 偵察
     - black-hacker: エントリポイント・認証フロー・データフロー分析
     - white-hacker: 既存セキュリティ機構の棚卸し
   - Phase 2: 脆弱性スキャン
     - Phase 1 の両結果を black-hacker に送り、OWASP Top 10 を中心にスキャン
   - Phase 3: 防御設計
     - Phase 2 の結果を white-hacker に送り、多層防御を設計
   - Phase 4: バイパス検証
     - Phase 3 の結果を black-hacker に送り、対策のバイパス可能性を検証

3. 各フェーズは SendMessage で対象 agent の結果を回収してから次へ進む。
   最後に Lead が全結果を受け取り、Step 3 の議論と Step 4 の統合を行う。
```

#### フォールバック（name / SendMessage が使えない場合）

`No agent named 'X' is currently addressable` 等で名前指定の通信が成立しない場合は、Lead が結果の受け渡しを担当して順次実行する:

1. `Agent(subagent_type=black-hacker)` を単独起動し、Phase 1 の偵察結果を Lead が受け取る。
2. `Agent(subagent_type=white-hacker)` を単独起動し、偵察結果をプロンプトに含めて既存防御を評価する。
3. Phase 2〜4 も対象 Agent をフェーズごとに単独起動し、直前までの成果物をプロンプトへ含める。
4. 各 Agent の返却結果を Lead が保持し、Step 3 の議論は同じ方式で最大2往復だけ再起動して引き渡す。

### Step 3: 議論フェーズ

```
SendMessage で次の往復を最大 2 回行う:
1. Black → White: 脆弱性・バイパス可能性を共有
2. White → Black: 修正した対策案を共有

「Black が新たな HIGH 以上のバイパスを指摘しない」または
「White の対策案に変更がない」状態になれば収束として終了する。
2 往復で収束しない場合は打ち切り、Lead が未解決点と両論をレポートへ併記する。
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

## 対象プロジェクトの自動判定

以下のファイルでプロジェクト種別を判定:
- `requirements.txt` / `pyproject.toml` → Python
- `package.json` → Node.js
- `go.mod` → Go
- `Cargo.toml` → Rust
- `pom.xml` / `build.gradle` → Java

種別に応じて重点チェック項目を調整する。
