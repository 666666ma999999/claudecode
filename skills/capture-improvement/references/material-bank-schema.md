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
