---
name: capture-improvement
description: プロジェクト改善を定量評価し、Material Bankに登録する。任意のプロジェクトから実行可能なグローバルスキル。定量的なBefore/Afterがない改善は登録しない。
user-invocable: true
argument-hint: "[改善メモ]"
allowed-tools:
  - Read
  - Write
  - Bash
  - Glob
  - Grep
  - Agent
  - AskUserQuestion
  - mcp__codex__codex
---

# capture-improvement スキル

プロジェクトの定量的な改善をキャプチャし、make_article の Material Bank に登録する。

**核心ルール**: 定量的な Before/After がない改善は記事にできない。登録しない。

## 起動トリガー

`/capture-improvement [改善メモ]`

例:
- `/capture-improvement PlaywrightMCPからchrome-devtoolsに変えたらテスト2倍速`
- `/capture-improvement Canonical Module統合で5,949行削除`
- `/capture-improvement プロンプト圧縮でAPI費用が月$50→$15に`

---

## 改善カテゴリ4分類

| カテゴリID | 名称 | 何を測るか | 記事化閾値 |
|-----------|------|----------|----------|
| `token_cost` | Token/Cost削減 | API token消費、呼び出し回数、月額コスト | 20%以上削減 |
| `speed` | Speed改善 | テスト実行時間、ビルド時間、API応答時間 | 30%以上改善 |
| `maintainability` | 保守堅牢性向上 | LOC削減、重複排除、カバレッジ、エラー率 | LOC 10%減 or カバレッジ10pt増 or エラー半減 |
| `dx` | DX/生産性向上 | 手動ステップ数、自動化率、セットアップ時間 | ステップ50%減 or 完全自動化 |

### カテゴリ別メトリクス

#### token_cost
- `token_per_request`: 1リクエストあたりのtoken消費
- `api_calls_per_task`: タスクあたりのAPI呼び出し回数
- `monthly_cost`: 月額APIコスト（USD）
- `prompt_lines`: プロンプトファイルの行数

#### speed
- `test_execution_time`: テスト実行時間（秒）
- `build_time`: ビルド/デプロイ時間（秒）
- `api_response_time`: API応答時間（ms）
- `workflow_duration`: ワークフロー全体の所要時間（分）
- `ci_pipeline_time`: CI/CDパイプライン実行時間

#### maintainability
- `lines_of_code`: コード行数（削減方向が改善）
- `duplicate_code_ratio`: 重複コード比率
- `test_coverage`: テストカバレッジ（%）
- `error_rate`: エラー発生率（回/日）
- `dependency_count`: 依存パッケージ数

#### dx
- `manual_steps`: 手動操作ステップ数
- `setup_time`: 環境セットアップ時間（分）
- `deploy_frequency`: デプロイ頻度（回/週）
- `automation_ratio`: 自動化率（%）

---

## 実行フロー

### STEP 1: 改善カテゴリ判定 + X投稿カテゴリ判定

1. ユーザーメモからキーワードで改善カテゴリを自動判定:

| キーワード | → 改善カテゴリ |
|----------|-------------|
| token, cost, 費用, API料金, 課金, プロンプト圧縮 | `token_cost` |
| 速度, 速い, 時間, 秒, 分, テスト, ビルド, 応答, speed | `speed` |
| 行数, 削除, 重複, リファクタ, カバレッジ, エラー率, 障害 | `maintainability` |
| 自動化, ステップ, 手動, セットアップ, デプロイ, hooks | `dx` |

2. 判定不能 → `AskUserQuestion` で確認（4カテゴリを選択肢提示）

3. X投稿カテゴリも判定:
   - Claude/AI/MCP/hooks/code関連 → `tech_tips`
   - 株/投資/市場関連 → `investment`
   - 経営/組織/取締役関連 → `ceo_perspective`
   - 判定不能 → `AskUserQuestion` で確認

### STEP 2: 定量メトリクス取得（C1 Agent: Git Archaeology）

**並列で2つのSubAgentを起動する:**

#### SubAgent A: Git自動取得（git repoの場合のみ）

以下を自動実行:
```bash
# 現在のプロジェクトがgitリポジトリか確認
git rev-parse --is-inside-work-tree 2>/dev/null

# 最近のコミットサマリー
git log --oneline -10

# 変更規模
git diff --stat HEAD~5..HEAD 2>/dev/null

# LOC変化（maintainabilityカテゴリ時）
git diff --stat HEAD~10..HEAD -- '*.py' '*.js' '*.ts' 2>/dev/null
```

改善カテゴリに応じた自動取得:
- `token_cost`: プロンプトファイル(*.md)の行数変化
- `speed`: テストファイル変更検出
- `maintainability`: LOC変化、テストファイル数変化、重複パターン検出
- `dx`: スクリプト(*.sh, Makefile)追加検出、設定ファイル変更

#### SubAgent B: ユーザーへのBefore/After必須質問

SubAgent Aの結果に関わらず、以下を必ず質問する:

改善カテゴリに応じた質問テンプレート:

**token_cost:**
- 「Before: 1リクエストあたり何token（or 月額いくら）でしたか？」
- 「After: 改善後はいくらですか？」

**speed:**
- 「Before: 改善前の実行時間は何秒（分）でしたか？」
- 「After: 改善後は何秒（分）ですか？」

**maintainability:**
- 「Before: 改善前のコード行数（or エラー頻度、カバレッジ）はいくつでしたか？」
- 「After: 改善後はいくつですか？」

**dx:**
- 「Before: 手動で何ステップ必要でしたか？（or セットアップ何分？）」
- 「After: 改善後は何ステップ（何分）ですか？」

**深掘りルール:**
- ユーザーが曖昧な回答をした場合（「かなり速くなった」等）→ 「具体的な数値はありますか？○○秒 → △△秒 のように」と再質問
- 深掘りは最大2回。2回質問しても数値が出ない → STEP 3 のゲートで判定

### STEP 2.5: Codex Deep-Dive（C2 Agent、任意）

登録ゲート前に、Codex MCPでコード変更の技術的文脈を深掘りする。

**実行条件**: ユーザーに「Codex MCPで詳細分析しますか？(y/N)」と確認。デフォルトNo（速度優先）。

Yesの場合、SubAgentを起動し `mcp__codex__codex` ツールを使用:

```
プロンプト:
「このプロジェクトの最近のgit変更を分析してください。
1. 変更対象コードのアーキテクチャ上の位置づけ（core / extension / config）
2. 変更の影響範囲（依存する他コンポーネント）
3. 技術的なトレードオフ（何を得て何を失ったか）
4. 他の開発者が同じ改善を再現するために必要なステップ」

sandbox: read-only
cwd: {現在のプロジェクトディレクトリ}
```

**C2の出力を以下に活用:**
- STEP 5 の `content` フィールドに技術的文脈を追加
- STEP 5 の `quality_score.reproducibility` の計算に使用（再現手順が具体的なら高スコア）
- STEP 5 の `tags` に技術パターン名を追加

---

### STEP 3: 登録ゲート判定

以下を**全て**満たさないと Material Bank に登録しない:

1. **改善カテゴリが特定されている**（4分類のいずれか）
2. **Before/After 数値ペアが最低1つある**
3. **改善方向である**（Before → After で良くなっている）
4. **カテゴリ別閾値を超えている**:

| カテゴリ | 閾値 | 計算方法 |
|---------|------|---------|
| `token_cost` | 20%以上削減 | `(before - after) / before * 100` |
| `speed` | 30%以上改善 | `(before - after) / before * 100` |
| `maintainability` | LOC 10%減 or カバレッジ10pt増 or エラー半減 | メトリクスに応じて判定 |
| `dx` | ステップ50%減 or 完全自動化 | `(before - after) / before * 100` or after == 0 |

**ゲート通過しない場合:**
```
❌ 登録ゲート未通過
  改善カテゴリ: speed
  Before: 120秒 → After: 110秒
  改善率: 8.3%（閾値: 30%以上）

  現時点では記事化に十分な改善幅がありません。
  改善を続けて、閾値を超えたら再度 /capture-improvement してください。
```
→ 登録せずに終了

**ゲート通過した場合:**
→ STEP 4 へ進む

### STEP 4: ストーリー構成（C3 Agent: Improvement Detector）

ユーザーメモ + gitデータ + プロジェクトのCLAUDE.md/task.md（あれば）を読み込み、以下を構成:

1. **Before状態**: 改善前の課題・痛み（具体的に）
2. **転機**: 何がきっかけで改善に着手したか
3. **After状態**: 改善後の状態（定量 + 定性）
4. **学び**: 汎用化可能な教訓
5. **失敗談**（あれば）: 改善過程での遠回りや失敗

プロジェクトのCLAUDE.md読み込みパス:
```
{現在のcwd}/CLAUDE.md
```

## STEP 5: Material Bank スキーマ変換 (M1 Agent)

品質スコア 3 軸計算・スキーマ変換・ID 採番ルール・素材生成パターンの詳細は `references/material-bank-schema.md` を参照。
