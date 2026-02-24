# /review-security — セキュリティ差分監査コマンド

## 概要
PR/ブランチの差分に対して Security Twin Agents（Black Hacker + White Hacker）による
セキュリティレビューを実行する。

## 使い方
```
/review-security              # 現在ブランチの main との差分を監査
/review-security PR#123       # 特定PRの差分を監査
/review-security src/auth/    # 特定ディレクトリをスポット監査
```

## 実行手順

### Step 1: 対象範囲の特定

引数に応じて対象を決定:
- 引数なし: `git diff main...HEAD` で差分ファイルを取得
- PR番号: `gh pr diff {number}` で差分ファイルを取得
- ディレクトリ: 指定パス配下の全ファイル

### Step 2: Black Hacker SubAgent 起動

Task tool で `black-hacker` エージェントを起動:

```
prompt: |
  以下の差分ファイルに対してセキュリティ分析を実行してください。

  対象ファイル:
  {差分ファイル一覧}

  分析スコープ:
  - 新規追加コードの脆弱性チェック
  - 変更箇所のセキュリティ影響分析
  - OWASP Top 10 カテゴリでの体系的チェック

  レポート形式で報告してください。
```

### Step 3: White Hacker SubAgent 起動

Black Hacker の結果を受けて `white-hacker` エージェントを起動:

```
prompt: |
  Black Hacker が以下の脆弱性を発見しました:
  {Black Hackerの報告}

  各脆弱性に対して:
  1. 妥当性の検証（偽陽性の排除）
  2. 具体的な修正コード提案
  3. テストケース提案
  4. 優先度の判定

  対策レポート形式で報告してください。
```

### Step 4: 統合レポート

以下の形式でレポートを出力:

```markdown
# Security Review: {ブランチ名 or PR#}
## Date: {日付}
## Scope: {差分ファイル数} files changed

### Summary
- 🔴 CRITICAL: x件
- 🟠 HIGH: x件
- 🟡 MEDIUM: x件
- 🔵 LOW: x件
- ⚪ INFO: x件

### Findings & Mitigations
（脆弱性と対策のペア一覧）

### Verdict
- ✅ PASS: セキュリティ問題なし
- ⚠️ CONDITIONAL: 軽微な問題あり（対策推奨）
- ❌ BLOCK: 重大な問題あり（修正必須）
```

### Step 5: 保存（オプション）

レポートを `.claude/workspace/security-review-{date}.md` に保存。

## 注意事項
- CRITICAL/HIGH が検出された場合、マージ前の修正を強く推奨
- 偽陽性の可能性がある場合、White Hacker の検証結果を重視
- 大規模な差分（50ファイル超）の場合、バッチ分割を検討
