---
name: project-recall
description: |
  プロジェクト復帰時のコンテキスト再構築スキル。Explore Agent + Codex MCP + 並列Agent Teamsで
  コードベース・履歴・Memory を統合分析し、復帰レポートを生成・Memory永続化する。
  キーワード: プロジェクト思い出す, 久しぶり, 何だったっけ, コンテキスト復元, 前回何してた, 忘れた,
  project recall, what was this, remind me, catch up, context restore
  NOT for: アクティブ作業中の進捗管理（→ task-progress）, 初回コードベース調査（→ codebase-investigation）
allowed-tools: "Read Glob Grep Agent"
metadata:
  author: masaaki-nagasawa
  version: 1.0.0
  category: productivity
  tags: [context-restore, memory, agent-teams, project-recall]
---

# プロジェクトリコールスキル

## シナリオ選択フロー

```
Q1. Memory（MEMORY.md + memory/）に十分な情報があるか？
    → Memory未読 → まずMemory読み込み → Q1再判定
    → 十分あり → Q2へ
    → 不十分/なし → Scenario A（完全リコール）

Q2. ユーザーの意図は何か？
    → 「全体像を思い出したい」「久しぶり」 → Scenario B（メモリ支援リコール）
    → 「{モジュール}の詳細を知りたい」 → Scenario C（モジュール深掘り）
    → 「前回の続き」「中断作業の再開」 → Scenario D（中断作業再開）
    → 「今どうなってる」「状態確認」 → Scenario E（クイック状態確認）
```

---

## Scenario A: 完全リコール

**トリガー**: Memory情報が不十分、初回復帰、「何だったっけ」

**Agent構成（3並列）:**

| Agent | Type | 役割 |
|-------|------|------|
| Explorer | Explore (very thorough) | コードベース構造・主要モジュール・設定ファイル・依存関係の把握 |
| Historian | general-purpose | git log/blame + task.md + CLAUDE.md で変更履歴・直近作業・課題を整理 |
| DocScanner | general-purpose | README, docs/, CLAUDE.md, .env.example 等からプロジェクト目的・運用情報を収集 |

**Explorerへの指示テンプレート:**
```
プロジェクト全体を very thorough で調査し、以下をレポートせよ:
1. ディレクトリ構造と各モジュールの役割
2. 主要な設定ファイル（docker-compose, config, .env.example等）
3. エントリポイント（main.py, app.py, Makefile等）
4. 外部依存（DB, API, MCP等）
5. テスト構成
```

**Historianへの指示テンプレート:**
```
以下を調査し、時系列でレポートせよ:
1. git log --oneline -30 で直近コミット概要
2. git log --since="3 months ago" --stat で変更規模
3. task.md / tasks/ があれば直近タスク状況
4. CLAUDE.md のプロジェクト固有情報
```

**出力:**
1. ユーザーへ: 統合サマリーレポート（構造 + 履歴 + 目的）
2. Memory保存: project-overview.md を新規作成 or 更新

---

## Scenario B: メモリ支援リコール

**トリガー**: Memoryに基本情報あり、「思い出したい」「久しぶり」

**Agent構成（2並列）:**

| Agent | Type | 役割 |
|-------|------|------|
| DiffAnalyzer | Explore (medium) | Memory最終更新以降の変更差分を検出 |
| StatusChecker | general-purpose | git status, docker状態, 依存変更, task.md 差分を確認 |

**出力:**
1. ユーザーへ: Memory内容の要約 + 差分レポート（「前回からの変更点」）
2. Memory更新: 既存Memory情報を最新化

---

## Scenario C: モジュール深掘り

**トリガー**: 「{モジュール名}の詳細」「{ファイル}の仕組み」

**Agent構成（2並列）:**

| Agent | Type | 役割 |
|-------|------|------|
| ModuleExplorer | Explore (very thorough) | 指定モジュールの構造・依存・API・データフロー |
| ContextBuilder | general-purpose | 関連するgit履歴・issue・コメントの収集 |

**出力:**
1. ユーザーへ: モジュール詳細レポート
2. Memory保存: `memory/topics/{module-name}.md` として追加

---

## Scenario D: 中断作業再開

**トリガー**: 「前回の続き」「中断したやつ」

**手順:**
1. `task-progress` スキルに委任（task.md / tasks/ の読み込みと状態確認）
2. Explore Agent (quick) で中断箇所周辺のコード状態を確認
3. 再開提案をユーザーに提示

**出力:**
1. ユーザーへ: 中断箇所 + 残タスク + 再開提案
2. Memory更新: 不要（task-progressが管理）

---

## Scenario E: クイック状態確認

**トリガー**: 「今どうなってる」「状態確認」

**エージェント不使用。** 以下を直接実行:

```
1. MEMORY.md を Read
2. git status + git log --oneline -5
3. docker ps（Docker プロジェクトの場合）
4. task.md があれば Read
```

**出力:** 5行以内のステータスサマリー

---

## メモリ保存ルール

### 必須（ファイルベース Memory）

| 保存先 | 内容 | タイミング |
|--------|------|-----------|
| `memory/project-overview.md` | プロジェクト全体像・目的・構成 | Scenario A/B 完了時 |
| `memory/topics/{name}.md` | モジュール別詳細 | Scenario C 完了時 |
| `memory/MEMORY.md` | インデックス更新 | 上記ファイル追加・更新時 |

### 保存時の注意

- 既存Memoryがあれば上書きではなく差分更新
- MEMORY.md は 200行以内を維持（インデックスのみ）
- コードスニペットは保存しない（パスと関数名で参照）

---

## 補完スキル連携表

| 状況 | 委任先スキル | 使い方 |
|------|------------|--------|
| コード構造の詳細調査が必要 | `codebase-investigation` | repomixで圧縮調査 |
| アクティブタスクの管理 | `task-progress` | Scenario D で委任 |
| SubAgent構成の最適化 | `execution-patterns` | 各シナリオのAgent委託時に準拠 |
| 大規模リファクタリングの調査 | `refactoring-guide` | リコール後の作業移行時 |
