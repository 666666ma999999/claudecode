# Prompt Templates for project-recall v2

SKILL.md から参照されるプロンプトテンプレート集。各テンプレートの `{{変数}}` は実行時にコンテキストから置換する。

---

## 1. Explorer (Scenario A)

```
プロジェクト「{{project_name}}」を very thorough で調査し、以下をレポートせよ:

1. ディレクトリ構造と各モジュールの役割
2. 主要な設定ファイル（docker-compose, config, .env.example等）
3. エントリポイント（main.py, app.py, Makefile等）
4. 外部依存（DB, API, MCP等）
5. テスト構成

作業ディレクトリ: {{cwd}}
```

---

## 2. Historian (Scenario A)

```
プロジェクト「{{project_name}}」の変更履歴を調査し、時系列でレポートせよ:

1. git log --oneline -30 で直近コミット概要
2. git log --since="3 months ago" --stat で変更規模
3. task.md / tasks/ があれば直近タスク状況
4. CLAUDE.md のプロジェクト固有情報

作業ディレクトリ: {{cwd}}
```

---

## 3. CodeAnalyst — Scenario A（全体分析）

Codex MCP (`mcp__codex__codex`) に送信するクエリ:

```
プロジェクト「{{project_name}}」（パス: {{cwd}}）の全体的な設計分析を行ってください。

分析観点:
1. 設計意図: なぜこのアーキテクチャが選ばれたか
2. アーキテクチャパターン: 使用されているパターン（MVC, Pipeline, Extension等）の識別
3. 技術的負債: リファクタリングが必要な領域
4. 依存関係リスク: 外部依存・バージョン固定・非推奨ライブラリ
5. 各項目に confidence: HIGH/MEDIUM/LOW を付与

コンテキスト:
- 主要ファイル構成: {{structure_summary}}
- 直近の変更概要: {{recent_changes_summary}}
```

---

## 4. CodeAnalyst — Scenario B（差分分析）

```
プロジェクト「{{project_name}}」の以下の差分について設計分析を行ってください。

差分概要:
{{diff_summary}}

分析観点:
1. 設計意図: この変更はなぜ行われたか
2. アーキテクチャへの影響: 既存パターンとの整合性
3. 技術的負債: 変更により生じた/解消された負債
4. 依存関係リスク: 新規依存・変更された依存
5. 各項目に confidence: HIGH/MEDIUM/LOW を付与
```

---

## 5. CodeAnalyst — Scenario C（モジュール分析）

```
プロジェクト「{{project_name}}」のモジュール「{{module_name}}」（パス: {{module_path}}）を分析してください。

分析観点:
1. 設計意図: このモジュールの責務と設計判断の理由
2. アーキテクチャパターン: モジュール内で使用されているパターン
3. 技術的負債: 改善が必要な箇所
4. 依存関係リスク: 他モジュールとの結合度・外部依存
5. 各項目に confidence: HIGH/MEDIUM/LOW を付与

コンテキスト:
- モジュール構造: {{module_structure}}
- 関連するgit履歴: {{module_git_history}}
```

---

## 6. Deep Dive 初回 (A+)

Codex MCP (`mcp__codex__codex`) に送信する深層分析クエリ:

```
プロジェクト「{{project_name}}」について、以下のテーマで深層分析を行ってください。

テーマ: {{deep_dive_theme}}

背景:
- Scenario A の統合レポートで以下が判明: {{scenario_a_findings}}
- Cross-Validation で以下の矛盾/未解決項目あり: {{unresolved_items}}

詳細分析の要求:
1. 上記テーマに関する設計判断の経緯と代替案
2. 現在の実装のトレードオフ分析
3. 潜在リスクと推奨アクション
4. 各項目に confidence: HIGH/MEDIUM/LOW を付与

回答は具体的なファイルパスと関数名を含めてください。
```

---

## 7. Deep Dive フォローアップ codex-reply (A+)

Codex MCP (`mcp__codex__codex-reply`) に送信するフォローアップクエリ:

```
前回の分析について追加質問があります。

前回回答の確認ポイント:
- 矛盾点: {{contradictions}}
- 未解決項目: {{unresolved}}
- 追加で知りたいこと: {{additional_questions}}

以下について掘り下げてください:
1. {{specific_question_1}}
2. {{specific_question_2}}

各項目に confidence: HIGH/MEDIUM/LOW を付与してください。
```

**注意:** このテンプレートは `mcp__codex__codex-reply` で使用。前回の codex 呼び出しで返された threadId を使用すること。最大2回まで。
