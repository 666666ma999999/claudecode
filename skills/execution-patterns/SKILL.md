---
name: execution-patterns
description: |
  実行パターン詳細ガイド。SubAgent委託テンプレート（5項目必須）、コンテキスト予算チェック
  （100行超→Extract-to-File）、データ分析委託パターン（Phase分割）、デバッグ鉄則
  （3-Fix Limit、根本原因特定まで修正禁止）、リファクタリング戦略（参考コード方式）。
  SubAgent委託時、デバッグ時、大量データ分析時、リファクタリング時に使用。
  キーワード: SubAgent, 委託, デバッグ, リファクタリング, データ分析, Extract-to-File
  NOT for: 単純なタスク実行、1ファイル修正、デバッグの根本原因分析手法のみ（→ debugging-guide）、リファクタリング戦略そのもの（→ refactoring-guide）
allowed-tools: [Read, Glob, Grep]
---

# 実行パターン詳細ガイド

## 1. SubAgent委託の必須条件と並列構成

### 委託必須条件（CLAUDE.md「SubAgent強制ルール」の実行詳細）

即答タスク以外で以下に該当する場合、メインAgent単独実装を禁止する:

| タスク規模 | 最低構成 | 起動タイミング |
|-----------|---------|---------------|
| **標準**（2ファイル以上 or 調査+実装+検証の2種以上） | Explore + Verify | Plan確定直後、実装開始前 |
| **大規模**（アーキ変更、Tasks 3件以上） | Explore + Implement + Verify | Plan確定直後、実装開始前 |

### 役割定義

| 役割 | 責務 | subagent_type | model | 起動条件 |
|------|------|--------------|-------|----------|
| **Explore** | 既存コード調査、影響範囲分析、パターン検索 | `Explore` | `haiku` | 常に最初に起動 |
| **Implement** | コード実装（1 Agent = 1ファイル or 1論理変更） | `general-purpose` | `sonnet` | 大規模タスク時 |
| **Verify** | テスト実行、動作確認、リグレッション検知 | `general-purpose` | `haiku` | 各バッチ終了時 |
| **Architecture** | 設計案比較、トレードオフ分析 | `Plan` | `opus` | feature-dev-hybrid Phase 4 |

> **コスト最適化**: Explore/Verify は haiku で十分（read-only操作中心）。Implement は sonnet。Architecture のみ opus。この構成で全 sonnet 比約60%コスト削減。Agent起動時に `model: "haiku"` 等を指定すること。

### 標準パターン（2-Agent並列）

```
1. Explore SubAgent → 既存コード調査（並列起動）
2. Main Agent → Explore結果を統合し、実装方針決定
3. Main Agent → 実装（1バッチ = 最大3タスク）
4. Verify SubAgent → バッチ検証（テスト実行・動作確認）
5. Main Agent → Verify結果確認 → 次バッチ or 完了
```

### 大規模パターン（3-Agent並列）

```
1. Explore SubAgent → 既存コード調査
2. Main Agent → Explore結果を統合し、タスク分配
3. Implement SubAgent A → ファイル群Aの実装（並列起動）
4. Implement SubAgent B → ファイル群Bの実装（並列起動）
5. Verify SubAgent → 各バッチ終了後に検証
6. Main Agent → 統合・接着・最終確認
```

### 委託テンプレート（5項目必須）

SubAgentにタスク委託時、以下を全て提供すること:

```
1. Goal: このタスクで達成すべきこと
2. Context: 関連ファイルパス・関数名・データフロー
3. Spec: 入出力の仕様（型・値の範囲・エッジケース）
4. Constraints: 既存コードとの整合性要件
5. Verification: テストコマンドと期待結果（fast_verify + final_verify）
```

**必要な情報が全て委託内容に含まれている**状態が理想。

### Verify SubAgentの委託テンプレート

```
1. Goal: バッチN（T1-T3）の変更が正しく動作することを検証
2. Context: 変更ファイル一覧、変更内容の概要
3. Spec:
   - fast_verify: [最短の実行可能な検証コマンド]
   - regression_check: [既存機能の破壊がないか確認するコマンド]
4. Constraints: テスト環境の前提条件（Docker, DB状態等）
5. Verification: 全テストPASSED + コンソールエラーゼロ
```

## 2. コンテキスト予算チェック（データ分析SubAgent向け）

SubAgentにデータ抽出・分析を委託する前に、以下の基準で予算超過リスクを判定する:

| 危険信号 | 閾値 | 対応 |
|---------|------|------|
| SQLクエリ結果の合計行数 | >100行 | Extract-to-File方式に切替 |
| レポート出力の想定行数 | >150行 | セクション分割して複数SubAgent |
| 1SubAgentあたりのSQLクエリ回数 | >10回 | フェーズ分割 |
| データ期間 × セグメント数 × 指標数 | >500セル | Extract-to-File方式必須 |

### Extract-to-File方式（強制パターン）

```
Phase 1: データ抽出SubAgent
  - SQLクエリ → Python → CSV/TSVファイルに出力
  - 出力先: project/boradmtg/tmp/{テーマ}_{YYYYMMDD}.csv
  - SubAgentのコンテキストにクエリ結果を保持しない

Phase 2: 分析・レポートSubAgent
  - Phase 1の出力ファイルを入力として読み込み
  - 分析 → Markdownレポート出力
  - 必要に応じてセクション別に複数SubAgentに分割
```

### 中間ファイルルール

| 項目 | 基準 |
|------|------|
| 配置先 | `project/boradmtg/tmp/` |
| 命名 | `{テーマ}_{YYYYMMDD}.csv` |
| ライフサイクル | レポート完成後に手動削除（.gitignoreで追跡対象外） |
| フォーマット | CSV（ヘッダー付き、UTF-8） |

### 禁止事項

- 100行超のSQLクエリ結果をSubAgentのコンテキストに保持すること
- データ抽出 + 分析 + レポート生成を1つのSubAgentに詰め込むこと
- 中間ファイルなしで大量データを次フェーズに渡すこと

## 3. データ分析委託パターン（委託前チェックリスト）

大量データ（SQL/Excel）を扱うSubAgent委託前に、以下のチェックリストを実行すること:

```
1. データ量見積もり
   - 行数 = 期間数 × セグメント数 × 指標数
   - 例: 8ヶ月 × 15セグメント × 20指標 = 2,400行 → Extract-to-File必須

2. 予算判定
   - 100行超 → Extract-to-File方式
   - 150行超出力 → セクション分割
   - 10回超クエリ → フェーズ分割

3. 分割判断
   - Phase 1: データ抽出 → CSV出力（1 SubAgent）
   - Phase 2: 分析・レポート（テーマ別に1 SubAgentずつ）
   - Deep Diveは1テーマ1SubAgent

4. 中間ファイル配置
   - 出力先: project/boradmtg/tmp/
   - 命名: {テーマ}_{YYYYMMDD}.csv
```

### 禁止事項

- **100行超のSQLクエリ結果をSubAgentのコンテキストに保持**すること
- **3フェーズ（抽出→分析→レポート）を1SubAgentに詰め込む**こと
- **中間ファイルなしで大量データを次フェーズに渡す**こと

## 4. デバッグ鉄則

**根本原因を特定するまで修正に着手しない。** 3回修正失敗で停止。

詳細は debugging-guide スキル参照。

## 5. リファクタリング戦略

参考コード方式で横展開。

詳細は refactoring-guide スキル参照。
