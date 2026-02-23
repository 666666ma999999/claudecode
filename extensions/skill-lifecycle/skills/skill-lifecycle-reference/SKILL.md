---
name: skill-lifecycle-reference
description: |
  スキルの作成・更新・管理の詳細ルール。配置場所判定（グローバル/プロジェクト）、
  メタデータフィールド基準（YAML frontmatter）、allowed-tools設定基準、
  スキル化判断フロー（Q0-Q3詳細版）、横展開チェック、重複チェック手順。
  スキル作成・更新・判断時に使用。実装完了後のスキル化判断にも参照。
  キーワード: スキル作成, スキル更新, SKILL.md, メタデータ, 横展開, 重複チェック
  NOT for: 通常の実装作業、コード編集
allowed-tools: "Read Glob Grep"
---

# スキルライフサイクル

## 自動認識

- スキルは `~/.claude/skills/` に配置すれば自動認識される
- CLAUDE.mdへのスキル参照追加・内容複製は**不要・禁止**

## 配置場所

グローバル: `~/.claude/skills/<スキル名>/SKILL.md` | プロジェクト: `project/.claude/skills/<スキル名>/SKILL.md`

| 条件 | 配置先 |
|------|--------|
| 複数プロジェクトで使う汎用パターン | `~/.claude/skills/`（グローバル） |
| 特定プロジェクトの固有ワークフロー | `project/.claude/skills/`（プロジェクト） |
| 特定CMS・外部システムの操作手順 | `project/.claude/skills/`（プロジェクト） |
| 言語・フレームワーク共通のパターン | `~/.claude/skills/`（グローバル） |

## メタデータフィールド基準

スキル作成・更新時、YAML frontmatterに以下のフィールドを設定すること:

| フィールド | 必須 | 説明 | 例 |
|-----------|------|------|-----|
| `name` | 必須 | kebab-case、フォルダ名と一致 | `my-skill-name` |
| `description` | 必須 | WHAT + WHEN + キーワード。1024文字以下。過剰発動防止のnegative triggerも含める | |
| `allowed-tools` | 推奨 | スキルが使用するツールを制限 | `"Read Glob Grep"` |
| `license` | 推奨 | ライセンス種別 | `proprietary` |
| `compatibility` | 該当時 | MCP・外部ツール・OS要件がある場合のみ | `"requires: Playwright"` |
| `metadata.category` | 推奨 | スキル分類 | `guide-reference`, `web-scraping`, `data-processing`, `workflow-automation`, `testing-qa`, `system-utility` |
| `metadata.tags` | 推奨 | 検索用タグ配列 | `[python, naming, api]` |

### allowed-tools 設定基準

| スキル用途 | 設定値 |
|-----------|--------|
| ガイド・リファレンスのみ | `"Read Glob Grep"` |
| Web情報取得を含む | `"Read Glob Grep WebFetch"` |
| コード生成・修正 | `"Bash Read Write Edit Glob Grep"` |
| Python実行を含む | `"Bash(python:*) Read Write Edit Glob Grep"` |
| ブラウザ自動化 | `"Bash(python:*) Bash(node:*) Read Write Edit Glob Grep WebFetch"` |

## スキル化判断フロー（実装完了時に毎回実行）

```
Q0. このスキルは特定プロジェクト専用か？
    → YES → プロジェクトスキルとして project/.claude/skills/ に配置
    → NO → グローバルスキルとして ~/.claude/skills/ に配置
    → 判断後、Q1へ

Q1. 今回の変更は以下のいずれかに該当するか？
    - 新機能追加
    - 新しいパターンの発見
    - バグ修正で再発しうる問題（定数値の誤り、インデックスずれ、キー名不整合等）
    - 既存スキルに記載された情報の誤り（コード修正でスキルの記載が古くなった場合）
    → NO → 終了
    → YES → Q2へ

Q2. この知見は今後も繰り返し使うか？または既存スキルの情報更新が必要か？
    → NO → 終了
    → YES → Q3へ

Q3. 既存スキルに追加・修正可能か？（~/.claude/skills/ を確認）
    → YES → 該当スキルに追記・修正（自動実行・確認不要）→ 終了
    → NO → ユーザーに確認「新規スキルを作成しますか？」
```

**重要**: コード修正が既存スキルに記載されたインデックス・定数・手順に影響する場合、スキルも同時に更新すること。コードとスキルの不整合は禁止。

## 修正完了後の自動振り返り（必須）

### 横展開チェック
- このパターンは他のシステム/サイトでも使えるか？
- 同様のエラーが他のスキルでも発生しうるか？
- 該当する場合: 関連スキルにも追記（ユーザー確認不要）

### スキル構成の最適化

| 状況 | 判断 |
|------|------|
| 特定システム専用の知見 | 既存スキルに追加 |
| 複数システムで共通の知見 | 汎用スキル作成を検討 |
| 既存の汎用スキルに該当 | そのスキルに追加 |

### 自動実行の範囲

**確認不要**: 既存スキルへの知見追記、トラブルシューティング追加、セレクタ・URL更新
**ユーザー確認**: 新規スキル作成、スキル統合・削除、大規模構造変更

## 重複チェック（新規作成前に必須）

```bash
ls ~/.claude/skills/ && grep -r "<機能キーワード>" ~/.claude/skills/*/SKILL.md
ls .claude/skills/ 2>/dev/null && grep -r "<機能キーワード>" .claude/skills/*/SKILL.md 2>/dev/null
```

| 状況 | 対応 |
|------|------|
| 完全重複 | 新規作成せず既存スキルを使用 |
| 部分重複 | 既存スキルに機能追加 |
| 類似機能で別目的 | 既存スキルからの参照を検討 |
