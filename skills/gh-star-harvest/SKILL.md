---
name: gh-star-harvest
description: GitHub で直近N日間にstarを集めたClaude関連リポを gh CLI で収集し、JSONLに保存する。X バズの副軸（客観指標）として /fetch-engagement とペアで運用する。
user_invocable: true
invocation: /gh-star-harvest [days=7] [topic=claude-code] [min_stars=50]
allowed-tools:
  - Bash
  - Read
  - Write
---

# GitHub Star Harvest

## 起動トリガー

- 週次の記事素材収集（推奨: 月曜朝）
- 特定トピックでの人気リポ調査
- `/fetch-engagement` と組み合わせて **X バズ × GitHub star** の2軸Material収集

## 引数

| 引数 | デフォルト | 例 |
|---|---|---|
| days | 7 | 14（過去2週間） |
| topic | claude-code | mcp / anthropic-claude / ai-agent |
| min_stars | 50 | 100 |

## 実行フロー

### STEP 1: パラメータ確定

引数が足りなければ、以下を `AskUserQuestion` で確認:
- 期間（日数）
- topic（1つ or 複数）
- star閾値

### STEP 2: harvest.sh 実行

```bash
bash ~/.claude/skills/gh-star-harvest/harvest.sh [days] [topic] [min_stars]
```

出力先: `~/.claude/metrics/gh-stars/YYYY-MM-DD_{topic}.jsonl`

### STEP 3: 要約表示

- 収集件数
- Top 10（stars順）
- 直近 pushed 日時（活発度）
- 言語分布

### STEP 3.5: 深掘り候補の選定（repomix連携）

description だけでは記事素材として判断できない Top リポは **`repomix` で中身を圧縮取得**して実装確認する。

- **役割分担**: `gh`（本スキル）= メタデータ (stars/pushed/description) / `repomix` = 実装コード中身
- **起動例**:
  ```
  "次の html_url を pack_remote_repository で圧縮して要約して:
   https://github.com/{full_name}"
  ```
- **対象**: Top 10 のうち description が曖昧 or 記事素材として使う予定のリポ
- **出力の保管**: repomix 結果は記事素材メモとして `output/research/` などに保存

これで「人気リポだが実はスカスカ」を事前検出できる。

### STEP 4: Material Bank への ingest 判定

Top 10 のうち、以下のリポは Material Bank の**候補**としてユーザーに提示:
- star 増加率が高い（`created` と `pushed` が近く、stars が多い）
- description に記事テーマ該当キーワードが含まれる
- まだ Material Bank にない
- **STEP 3.5 で実装中身を確認済み**（深掘りしたリポは信頼度が上がる）

ユーザー承認後、`training_data/materials/tech_tips.jsonl` に追記（スキーマは既存に準拠）。

### STEP 5: 次回実行の推奨

- 前回実行との差分（新規登場リポ / star 急増）を提示
- 次回の推奨パラメータ（例: topic を `mcp` に変えると良い等）

## 出力ファイル

```
~/.claude/metrics/gh-stars/
├── 2026-04-21_claude-code.jsonl
├── 2026-04-21_mcp.jsonl
└── 2026-04-28_claude-code.jsonl
```

### JSONL スキーマ（1行1リポ）

```json
{
  "full_name": "affaan-m/everything-claude-code",
  "stargazers_count": 162368,
  "description": "The agent harness performance optimization system...",
  "pushed_at": "2026-04-20T10:00:00Z",
  "created_at": "2025-11-15T...",
  "html_url": "https://github.com/affaan-m/everything-claude-code",
  "topics": ["claude-code", "agent"],
  "language": "Python"
}
```

## 2軸運用パターン

```
月曜朝:      /gh-star-harvest 7 claude-code 50      ← GitHub側
火〜金夜:    /fetch-engagement --urls-from-candidates ← X側
週末:        両JSONL を統合して記事素材として分析
```

## 注意

- **rate limit**: `gh` 認証済トークンで 5000req/時。通常用途で枯渇しない
- **topic 指定が鍵**: `claude` で検索するとノイズ大量。**`topic:xxx` で絞る**
- **grep 禁止**: JSONL は `jq` で扱う（env-factcheck 原則）

## 関連スキル

- `/fetch-engagement` - X側の実測（2軸の主軸）
- `codebase-investigation` / `repomix` - Top10リポの中身を深掘り（メタデータ→コード分析の橋渡し、STEP 3.5参照）
- `/generate-x-article` - 集めた素材で記事生成
- `env-factcheck` - 実使用計測（自分 vs 世界）
