---
name: project-recall
description: |
  プロジェクト復帰時のコンテキスト再構築スキル。Explore Agent + Codex MCP + 並列Agent Teamsで
  コードベース・履歴・Memory を統合分析し、復帰レポートを生成・Memory永続化する。
  Phase Protocol（並列探索→クロス検証→統合）で調査品質を保証。
  キーワード: プロジェクト思い出す, 久しぶり, 何だったっけ, コンテキスト復元, 前回何してた, 忘れた,
  project recall, what was this, remind me, catch up, context restore
  NOT for: アクティブ作業中の進捗管理（→ task-progress）, 初回コードベース調査（→ codebase-investigation）
allowed-tools: "Read Glob Grep Agent mcp__codex__codex mcp__codex__codex-reply"
metadata:
  author: masaaki-nagasawa
  version: 2.0.0
  category: productivity
  tags: [context-restore, memory, agent-teams, project-recall, codex-mcp, phase-protocol]
---

# プロジェクトリコールスキル v2

## シナリオ選択フロー & エスカレーションパス

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

**エスカレーションパス:** E → B → A → A+（情報不足時に上位へ段階的に深化）

---

## Phase Protocol（全シナリオ共通）

Agent Teamsを使うシナリオ（A/B/C/A+）は以下の3フェーズで実行:

| Phase | 名称 | 内容 |
|-------|------|------|
| P1 | 並列探索 | 各Agentが独立に調査を実行（Agent Teams並列起動） |
| P2 | クロス検証 | Agent結果を Cross-Validation マトリクスで照合（後述） |
| P3 | 統合 | 検証済み結果を統合レポートにまとめ、Memory保存 |

- P1完了後、P2で矛盾が検出された場合 → codex-reply で追加質問 or A+へエスカレーション
- P3の統合レポートには各項目の confidence タグ（HIGH/MEDIUM/LOW）を付与

---

## Codex Integration — CodeAnalyst ロール

Scenario A/B/C で共通利用する Codex MCP ベースの分析ロール。

**CodeAnalyst の分析観点（5項目）:**
1. 設計意図（なぜこう書かれたか）
2. アーキテクチャパターン識別
3. 技術的負債・リスク領域
4. 依存関係リスク
5. 各項目に `confidence: HIGH/MEDIUM/LOW`

**Codex呼び出し:** `mcp__codex__codex` に分析クエリを送信。プロンプトは `references/prompt-templates.md` を参照。

**フォールバック:** Codex MCP 利用不可時 → CodeAnalyst を general-purpose SubAgent に降格（Grep/Read ベース分析に切替）。エラーメッセージに「Codex unavailable」を含む場合に自動判定。

---

## Scenario A: 完全リコール

**トリガー**: Memory情報が不十分、初回復帰、「何だったっけ」

**Agent構成（P1: 3並列）:**

| Agent | Type | 役割 |
|-------|------|------|
| Explorer | Explore (very thorough) | コードベース構造・主要モジュール・設定ファイル・依存関係 |
| Historian | general-purpose | git log/blame + task.md + CLAUDE.md で変更履歴・直近作業・課題 |
| CodeAnalyst | Codex MCP | 設計意図・アーキテクチャパターン・技術的負債の分析 |

プロンプトテンプレート: `references/prompt-templates.md` の Explorer / Historian / CodeAnalyst(A) を使用。

**出力（P3）:** 統合サマリーレポート（構造+履歴+設計分析、confidence付き）。Memory: `project-overview.md` + `{project}-codex-analysis.md`

---

## Scenario B: メモリ支援リコール

**トリガー**: Memoryに基本情報あり、「思い出したい」「久しぶり」

**Agent構成（P1: 2並列）:**

| Agent | Type | 役割 |
|-------|------|------|
| DiffAnalyzer | Explore (medium) | Memory最終更新以降の変更差分を検出 |
| CodeAnalyst | Codex MCP | 差分箇所の設計意図・影響範囲を分析 |

**出力（P3）:** Memory要約 + 差分レポート + Codex分析（confidence付き）。Memory既存情報を最新化。

---

## Scenario C: モジュール深掘り

**トリガー**: 「{モジュール名}の詳細」「{ファイル}の仕組み」

**Agent構成（P1: 2並列）:**

| Agent | Type | 役割 |
|-------|------|------|
| ModuleExplorer | Explore (very thorough) | 指定モジュールの構造・依存・API・データフロー |
| CodeAnalyst | Codex MCP | モジュールの設計意図・パターン・改善余地を分析 |

**出力（P3）:** モジュール詳細レポート。`memory/topics/{module-name}.md` + `{module-name}-codex-analysis.md` として保存。

---

## Scenario D: 中断作業再開

**トリガー**: 「前回の続き」「中断したやつ」

**手順:**
1. `task-progress` スキルに委任（task.md / tasks/ の読み込みと状態確認）
2. Explore Agent (quick) で中断箇所周辺のコード状態を確認
3. 再開提案をユーザーに提示

**出力:** 中断箇所 + 残タスク + 再開提案。Memory更新不要（task-progressが管理）。

---

## Scenario E: クイック状態確認

**トリガー**: 「今どうなってる」「状態確認」。**エージェント不使用。**

直接実行: MEMORY.md Read → git status + git log --oneline -5 → docker ps（Docker時） → task.md Read

**出力:** 5行以内のステータスサマリー

---

## Deep Dive Protocol (A+)

**トリガー**: Scenario A完了後の深掘り、またはCross-Validationでの矛盾検出時。

**手順:**
1. Scenario A の P3 統合レポートから深掘りテーマを特定
2. `mcp__codex__codex` で初回深層分析クエリを送信（テンプレート: Deep Dive 初回）
3. 結果を評価し、不明点があれば `mcp__codex__codex-reply` で最大2回フォローアップ
4. フォローアップ間で前回回答の矛盾点・未解決項目を明示的に指摘

**制約:**
- codex-reply は最大2回（計3ターン: 初回 + reply×2）
- threadId はセッション内のみ使用、Memory に保存しない
- confidence: LOW の項目はレポートに注記するが Memory には保存しない

**出力:** `memory/topics/{theme}-deep-analysis.md` として保存（HIGH/MEDIUM のみ）

---

## Cross-Validation マトリクス

P2（クロス検証）フェーズで Agent 結果を照合する際の判定基準:

| Explorer/DiffAnalyzer 結果 | CodeAnalyst 結果 | confidence | アクション |
|---------------------------|-----------------|-----------|-----------|
| 一致 | 一致 | HIGH | そのまま採用 |
| 発見あり | 言及なし | MEDIUM | レポートに記載（片方のみ検出） |
| 言及なし | 発見あり | MEDIUM | レポートに記載（片方のみ検出） |
| 矛盾 | 矛盾 | LOW | codex-reply で追加質問、解決しなければ A+ へ |

- HIGH/MEDIUM → P3 統合レポートに含める
- LOW → レポートに注記付きで記載、ユーザーに判断を委ねる

---

## メモリ保存ルール

| 保存先 | 内容 | タイミング |
|--------|------|-----------|
| `memory/project-overview.md` | プロジェクト全体像・目的・構成 | A/B 完了時 |
| `memory/topics/{name}.md` | モジュール別詳細 | C 完了時 |
| `memory/topics/{name}-codex-analysis.md` | Codex分析結果（設計意図・パターン・負債） | A/B/C CodeAnalyst使用時 |
| `memory/topics/{theme}-deep-analysis.md` | Deep Dive 統合結果 | A+ 完了時 |
| `memory/MEMORY.md` | インデックス更新 | 上記ファイル追加・更新時 |

**保存時の注意:**
- 既存Memoryがあれば上書きではなく差分更新
- MEMORY.md は 200行以内を維持（インデックスのみ）
- コードスニペットは保存しない（パスと関数名で参照）
- confidence: HIGH/MEDIUM のみ保存。LOW は保存しない
- codex-reply の threadId は保存しない（セッション限り）

---

## 補完スキル連携表

| 状況 | 委任先スキル | 使い方 |
|------|------------|--------|
| コード構造の詳細調査が必要 | `codebase-investigation` | repomixで圧縮調査 |
| アクティブタスクの管理 | `task-progress` | Scenario D で委任 |
| SubAgent構成の最適化 | `execution-patterns` | 各シナリオのAgent委託時に準拠 |
| 大規模リファクタリングの調査 | `refactoring-guide` | リコール後の作業移行時 |
| 実装完了後のチェック | `implementation-checklist` | リコール→実装移行時に発動 |
