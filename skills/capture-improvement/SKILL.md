---
name: capture-improvement
description: プロジェクト改善を定量評価し、Material Bankに登録する。任意のプロジェクトから実行可能なグローバルスキル。定量的なBefore/Afterがない改善は登録しない。
user_invocable: true
invocation: /capture-improvement [改善メモ]
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

### STEP 5: Material Bank スキーマ変換（M1 Agent: Material Synthesizer）

#### 品質スコア3軸計算

| 軸 | 重み | 計算方法 |
|---|---|---|
| `metric_significance` | 50% | 改善率 / カテゴリ閾値 の比率でスコア化。閾値の2倍以上 = 9.0-10.0、閾値ちょうど = 5.0-6.0 |
| `reproducibility` | 30% | 再現に必要なステップ数で判定。1ステップ = 9.0、2-3ステップ = 7.0、4以上 = 5.0 |
| `novelty` | 20% | 初回は一律 6.0。Feedback Loopデータ蓄積後に実績ベースで調整 |

`composite = metric_significance * 0.5 + reproducibility * 0.3 + novelty * 0.2`

#### スキーマ変換

1改善から1-3件の素材を生成:

```json
{
  "id": "mat_XXX",
  "category": "tech_tips",
  "type": "experience | insight | data_point | success",
  "title": "短いタイトル（改善内容を端的に）",
  "content": "STEP 4のストーリー（Before→転機→After→学び）を散文化",
  "key_numbers": ["180s→90s", "50%改善", "3ファイル変更"],
  "improvement_category": "speed",
  "metrics": {
    "category": "speed",
    "items": [
      {
        "name": "test_execution_time",
        "before": "180s",
        "after": "90s",
        "delta": "-50%",
        "source": "user_input"
      }
    ],
    "gate_passed": true,
    "gate_reason": "50% speed improvement exceeds 30% threshold"
  },
  "quality_score": {
    "metric_significance": 9.0,
    "reproducibility": 8.0,
    "novelty": 6.0,
    "composite": 7.9
  },
  "emotion": "驚き | 達成感 | 確信",
  "reusable": true,
  "used_count": 0,
  "tags": ["プロジェクト名", "技術キーワード1", "技術キーワード2"],
  "collected_at": "YYYY-MM-DD",
  "source": "project_improvement"
}
```

#### ID採番ルール

- Material Bank パスは `~/Desktop/biz/make_article/config/categories.yaml` の `material_bank` フィールドを参照する:
  - `tech_tips` → `training_data/materials/tech_materials.jsonl`
  - `investment` → `training_data/materials/investment_materials.jsonl`
  - `ceo_perspective` → `training_data/materials/ceo_materials.jsonl`
- 絶対パス: `~/Desktop/biz/make_article/{material_bank}`
- 既存JSONLから最大IDを確認し、`mat_XXX` の連番で採番
- ファイルが空の場合は `mat_001` から開始

#### 素材生成パターン

1改善から以下の素材を生成（該当するもののみ）:

| # | type | 内容 | 生成条件 |
|---|------|------|---------|
| 1 | `experience` | Before→After のストーリー全体 | 常に生成 |
| 2 | `data_point` | metrics の数値データのみ抽出 | key_numbersが2つ以上の場合 |
| 3 | `insight` | 学び・汎用化された教訓 | STEP 4で「学び」が具体的な場合 |

### STEP 6: ユーザー確認 + 書き込み

変換結果を表示して確認:

```
## 素材プレビュー

**改善カテゴリ:** Speed改善
**登録ゲート:** ✅ 通過（50%改善、閾値30%）
**品質スコア:** 7.9 / 10.0

### 素材 #1 (experience)
- **タイトル:** Playwright→chrome-devtools MCP切替でテスト2倍速
- **メトリクス:** test_execution_time 180s → 90s (-50%)
- **タグ:** rohan, MCP, playwright, chrome-devtools
- **キーナンバー:** 180s→90s, 50%改善, 3ファイル変更

### 素材 #2 (insight)
- **タイトル:** MCP選定基準: 速度 > 安定性 > エコシステム
- **内容:** ブラウザ自動化MCPは...（学びの詳細）

📝 この素材としてMaterial Bankに記録しますか？(OK/修正/スキップ)
```

- **OK** → STEP 7 へ
- **修正** → ユーザーの修正を反映して再表示
- **スキップ** → 記録せず終了

### STEP 7: JSONL追記 + 次アクション提案

1. **Staging Queue に追記**（CWD制限時のフォールバック、常に書き込み可能）:
   - パス: `~/.claude/state/improvement-queue.jsonl`
   - 1行1JSONオブジェクト形式。Material Bank エントリに加え `source_project`, `captured_at`, `status: "pending_ingest"` を付与
   - make_article セッションで `/ingest-improvements` 実行時に Material Bank に取り込まれる

1-B. **SQLite dual-write**（JSONL書き込み成功後のみ実行。失敗はサイレントでOK。JSONLがprimary）:
   ```bash
   # ~/.claude/state/improvement.db が存在するときだけ実行
   # Bash ヒアドキュメントではなくPython parameterized query でSQLインジェクション対策
   python3 - << 'PYEOF' 2>/dev/null || true
   import sqlite3, json, hashlib, os
   from pathlib import Path

   DB = Path.home() / ".claude" / "state" / "improvement.db"
   if not DB.exists():
       raise SystemExit(0)  # DBがなければ何もしない（JSONL優先）

   # 直前に追記したJSONLの最終行を読む（STEP 7-1で書いた内容）
   QUEUE = Path.home() / ".claude" / "state" / "improvement-queue.jsonl"
   lines = QUEUE.read_text(encoding="utf-8").splitlines() if QUEUE.exists() else []
   if not lines:
       raise SystemExit(0)  # 空ファイル → dual-writeスキップ（JSONL primary が未書き込みなので当然）
   ENTRY = json.loads(lines[-1])

   try:
       fp_src = (ENTRY.get("source_project","") +
                 ENTRY.get("captured_at","") +
                 ENTRY.get("title",""))
       fingerprint = hashlib.sha256(fp_src.encode()).hexdigest()[:16]

       metrics = ENTRY.get("metrics", {}).get("items", [])
       first = metrics[0] if metrics else {}
       bm = json.dumps({"name": first.get("name",""),
                        "value": first.get("before","")}, ensure_ascii=False) if first else None
       am = json.dumps({"name": first.get("name",""),
                        "value": first.get("after","")}, ensure_ascii=False) if first else None
       try:
           delta = float(str(first.get("delta","0%")).lstrip("-").replace("%",""))
       except (ValueError, AttributeError):
           delta = None
       composite = ENTRY.get("quality_score", {}).get("composite", None)

       con = sqlite3.connect(str(DB))
       con.execute("""
           INSERT OR IGNORE INTO improvements
           (fingerprint, captured_at, source_project, category, x_category,
            status, title, content, before_metric, after_metric,
            delta_pct, composite_score, raw_json)
           VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)
       """, (
           fingerprint,
           ENTRY.get("captured_at",""),
           ENTRY.get("source_project",""),
           ENTRY.get("improvement_category", ENTRY.get("category","")),
           ENTRY.get("x_category","tech_tips"),
           "pending_ingest",
           ENTRY.get("title",""),
           ENTRY.get("content",""),
           bm, am, delta, composite,
           json.dumps(ENTRY, ensure_ascii=False)
       ))
       con.commit()
       con.close()
   except Exception:
       pass  # サイレント失敗 — JSONLがprimary
   PYEOF
   ```
   SQLite dual-writeは将来のクエリ性能のためだが、JSONLが主データ。DB破損時はJSONLから `python3 scripts/migrate_jsonl_to_sqlite.py` で再構築可能。

2. Material Bank に追記（CWDが make_article の場合のみ直接書き込み）:
   - パスは `categories.yaml` の `material_bank` フィールドを参照（ID採番ルール参照）
   - 1行1JSONオブジェクト形式
   - ファイルが存在しない場合は新規作成
   - CWD制限で書き込めない場合はスキップ（Staging Queue があるため問題なし）

2. 追記後の状態を表示:
   ```
   ✅ Material Bank に 2 素材を追加しました

   カテゴリ: tech_tips
   素材総数: 2件（+2）
   品質スコア平均: 7.9
   ```

3. 次アクション提案:
   ```
   📝 次のアクション:
   1. このまま短文投稿を生成 → make_article ディレクトリで /generate-x-post [キーワード]
   2. このまま長文記事を生成 → make_article ディレクトリで /generate-x-article [トピック]
   3. 別の改善をキャプチャ → /capture-improvement [メモ]
   ```

---

## 注意事項

- **Material Bank の書き込みパスは絶対パスを使用する**: `~/Desktop/biz/make_article/training_data/materials/`
- このスキルはどのプロジェクトディレクトリからでも実行可能
- git情報は現在のcwdのリポジトリから取得する
- Codex MCP分析（C2 Agent）はPhase B実装。現在はスキップ
