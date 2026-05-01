# /review - Codexコードレビューコマンド（1段統合）

変更内容をCodexで**1回のプロンプト**にまとめて仕様準拠＋コード品質の両観点でレビューする。
従来の Stage 1 / Stage 2 別呼び出しは廃止（トークン節約のため）。`--spec` / `--quality` は片観点のみを単独で実行したい場合の明示オプションとして残す。
批判的・敵対的視点で前提・設計の妥当性を疑うレビューが必要な場合は `--mode=challenge` を使う（旧 `/adversarial-review` を吸収）。

## 引数

```
/review [オプション]
```

| オプション | 説明 |
|-----------|------|
| (なし) | **デフォルト**: 仕様準拠 + コード品質を 1 プロンプトで実行（Codex 1 回） |
| --spec | 仕様準拠観点のみ単独実行（明示時のみ） |
| --quality | コード品質観点のみ単独実行（明示時のみ） |
| --mode=challenge | **敵対的レビュー**: 前提・設計判断・ロジック妥当性を批判的に検証（旧 `/adversarial-review`） |
| --staged | ステージング済みの変更のみレビュー |
| --file PATH | 特定ファイルのみレビュー |
| --last-commit | 直前のコミットをレビュー |

`--spec` / `--quality` / `--mode=challenge` は `--staged` / `--file` / `--last-commit` と組み合わせ可能。
`--mode=challenge` は `--spec` / `--quality` とは排他（敵対モードは独立した観点のため）。

## 実行手順

### 1. 変更内容の取得

```bash
# デフォルト: 全変更
git diff HEAD

# --staged: ステージング済みのみ
git diff --cached

# --last-commit: 直前のコミット
git show HEAD

# --file: 特定ファイル
git diff HEAD -- {PATH}
```

### 2. task.md の確認（存在する場合）

task.md があれば以下をコンテキストに含める:
- タスクの目的・背景
- 成功基準
- 前提条件 / 変更禁止ファイル

### 3. Codex に 1 段統合レビュー依頼

`mcp__codex__codex` を 1 回だけ呼び、以下のプロンプトで両観点を同時に取得する:

```
以下の変更を、仕様準拠とコード品質の両観点で 1 度にレビューせよ。

## コンテキスト
タスク目的: {task.md の目的 or "不明"}
成功基準: {task.md の成功基準 or "不明"}
前提条件: {task.md の前提 or "記載なし"}

## 変更内容
{git diff 出力}

## 検証観点

### A. 仕様準拠（必須）
A1. 入出力の仕様を満たしているか
A2. エッジケースの処理が要件通りか
A3. 期待される動作との乖離はないか
A4. 追加・変更されたパラメータの全チェーン（定義 → dispatcher → 実メソッド）で値が正しく伝搬しているか
A5. Optional パラメータでデフォルト値に隠れて未接続になっているケースはないか

### B. コード品質（必須）
B1. バグ・エラー: 明らかなバグ、エッジケース漏れ
B2. セキュリティ: 脆弱性、機密情報の露出
B3. パフォーマンス: 非効率なコード、N+1 問題
B4. 可読性: 命名、コメント、構造
B5. テスト: テストカバレッジ、テストケース漏れ
B6. 設計: SOLID 原則、DRY 違反

## 出力形式
以下のテンプレートで 1 度に報告。仕様違反があれば必ず Critical Issues に上げること。

### Critical Issues (修正必須)
- [ ] [SPEC|QUALITY] 説明

### Warnings (検討推奨)
- [ ] [SPEC|QUALITY] 説明

### Suggestions (任意改善)
- [SPEC|QUALITY] 説明

### Good Points (良い点)
- 説明

### 総合判定
- 仕様準拠: PASS / FAIL（理由）
- 総合: APPROVE / CONDITIONAL / REJECT
```

### 4. レビュー結果の取り扱い

- Critical Issues に **[SPEC]** が含まれる → 修正してから再 `/review`
- Critical Issues に **[QUALITY]** のみ → 修正後の再レビューは任意
- Warnings / Suggestions → 任意修正

## 単独観点モード（明示時のみ）

`--spec` / `--quality` 指定時は片観点のみで Codex を呼ぶ。
通常はデフォルト（1 段統合）を使うこと。単独モードは「直前のレビューで一方の指摘を修正したので片側だけ再確認したい」等の限定用途。

### `--spec` プロンプト
上記プロンプトの「### A. 仕様準拠」と「## 出力形式」の SPEC 行のみ依頼。

### `--quality` プロンプト
上記プロンプトの「### B. コード品質」と「## 出力形式」の QUALITY 行のみ依頼。

## 注意事項

- 変更がない場合は「レビュー対象なし」と報告
- 大量の変更（500 行超）は要約モードで実行
- 1〜2 ファイル / 100 行未満の小修正は **`/review` 自体を省略してよい**（`implementation-checklist-pending.sh` 側でも閾値ガード済み）
- 認証 / 認可 / 外部入力受付 / 秘密情報を含む変更は閾値未満でも `/review` 必須
- Codex のレスポンスをそのまま表示（加工しない）
- レビュー結果は task.md に追記しない（別途判断）

## 使用例

```bash
# 全変更を 1 段レビュー（推奨）
/review

# ステージング済みのみ
/review --staged

# 特定ファイル
/review --file src/api/handler.py

# 直前のコミット
/review --last-commit

# 仕様だけ再確認したい場合
/review --spec --staged
```
