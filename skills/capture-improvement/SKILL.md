---
name: capture-improvement
description: |
  改善・体験談・気付きを Material Bank に登録(全プロジェクト可)。定量=metrics付き/質的=type別登録。
  トリガー: /capture-improvement, これ記事化したい, 素材化, マテリアルに, これ記事ネタ,
  改善した, 速くなった, 削減, 失敗した, 学んだ。
  NOT for: 1行アイデアメモ→/x-stock, 決定/教訓のwiki記録→/save
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

## 発火・詳細（description から移設 2026-07-03）

プロジェクト改善・体験談・気付きを Material Bank に登録する。任意のプロジェクトから実行可能なグローバルスキル。

- 定量モード (Before/After あり): improvement_category + metrics + quality_score 付き登録
- 質的モード (数値なし): type=experience/insight/failure 等で登録（mat_001/002 同等構造）

プロジェクトの改善・体験談・気付きをキャプチャし、make_article の Material Bank に登録する。

**運用ルール**:
- **定量モード**: Before/After 数値ペアあり → improvement_category + metrics 付きで登録（記事化閾値ゲート適用）
- **質的モード**: 数値なし or 質的体験 → type=experience/insight/failure 等で登録（数値なし OK・mat_001/002 同等構造を目指す）
- 両モードとも AskUserQuestion は最大 1 回まで（過剰質問禁止）

## 起動トリガー

`/capture-improvement [メモ]` または自然言語トリガー（description 参照）

例（定量）:
- `/capture-improvement PlaywrightMCPからchrome-devtoolsに変えたらテスト2倍速`
- `/capture-improvement Canonical Module統合で5,949行削除`
- `/capture-improvement プロンプト圧縮でAPI費用が月$50→$15に`

例（質的）:
- 「これ記事化したい: PassVault 構築譚」
- 「素材化: iPhone 同期を無料 git で組もうとして 2 時間で諦めた話」
- 「これ記事ネタ: macOS の TCC で Desktop 保護にハマった」

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

### STEP 3: モード判定 + 登録ゲート

#### 3a. モード判定

STEP 2 の結果から以下を判定:

| 条件 | モード |
|---|---|
| Before/After 数値ペアあり + 改善方向 | **定量モード** → 3b へ |
| 数値ペアなし or 改善方向でない（失敗談/比較検証含む） | **質的モード** → 3c へ |

#### 3b. 定量モード 登録ゲート（既存ルール維持）

以下を**全て**満たすこと:

1. 改善カテゴリが特定されている（4分類のいずれか）
2. Before/After 数値ペアが最低1つある
3. 改善方向である
4. カテゴリ別閾値を超えている:

| カテゴリ | 閾値 | 計算方法 |
|---------|------|---------|
| `token_cost` | 20%以上削減 | `(before - after) / before * 100` |
| `speed` | 30%以上改善 | `(before - after) / before * 100` |
| `maintainability` | LOC 10%減 or カバレッジ10pt増 or エラー半減 | メトリクスに応じて判定 |
| `dx` | ステップ50%減 or 完全自動化 | `(before - after) / before * 100` or after == 0 |

**ゲート未通過**: 質的モード（3c）へフォールバック（**捨てない**）。閾値未達は「失敗談・遠回り」として価値があるため。

#### 3c. 質的モード 登録ゲート

以下を満たすこと:

1. **type が特定されている**: `experience` / `insight` / `data_point` / `anecdote` / `failure` / `success` のいずれか
   - キーワード判定（不明なら content から LLM 推定）:
     - `experience`: 「やってみた」「構築した」「使った」
     - `failure`: 「失敗」「諦めた」「ハマった」「沼った」
     - `insight`: 「気付いた」「分かった」「学んだ」
     - `anecdote`: 「笑った」「びっくりした」「想定外」
2. **content が最低 500 字以上**（短すぎる→ x-stock に降格を推奨）
3. **症状/原因/解決のいずれか 2 つ以上が抽出できる**（content 構造判定）

**質的モード未通過**: 「情報不足のため `/x-stock` でタイトル保存を推奨」と提示して終了。**捨てない**。

→ STEP 4 へ進む（モード問わず）

### STEP 4: ストーリー構成（C3 Agent: Improvement Detector）

ユーザーメモ + gitデータ + プロジェクトのCLAUDE.md/task.md（あれば）+ 直近会話履歴を読み込み、以下を構成:

**定量モード**（既存）:
1. **Before状態**: 改善前の課題・痛み（具体的に）
2. **転機**: 何がきっかけで改善に着手したか
3. **After状態**: 改善後の状態（定量 + 定性）
4. **学び**: 汎用化可能な教訓
5. **失敗談**（あれば）: 改善過程での遠回りや失敗

**質的モード**（新規・mat_001/002 構造踏襲）:
1. **症状**: 起きた現象（症状①②③で構造化）
2. **原因**: なぜ起きたか（仕様 / 設定 / 環境）
3. **解決手順**: 具体コマンド・設定変更（再現可能なレベル）
4. **再発防止**: 多層防御（Layer 1, 2, 3 ... 等の整理推奨）
5. **やってはいけない 10 ルール**（任意・mat_001 パターン）
6. **1 行ルール**: 暗記用要約
7. **効果検証**: 解決後の動作確認（あれば）

プロジェクトのCLAUDE.md読み込みパス:
```
{現在のcwd}/CLAUDE.md
```

## STEP 5-7: Material Bank スキーマ変換 (M1 Agent) → ユーザー確認 → JSONL 追記

STEP 5（品質スコア 3 軸計算・スキーマ変換・ID 採番ルール・素材生成パターン）、STEP 6（ユーザー確認プレビュー）、STEP 7（Staging Queue / SQLite / Material Bank への書き込みと次アクション提案）の全文は `references/material-bank-schema.md` を参照。STEP 7 の JSONL 追記まで完了して初めてこのスキルは完了。
