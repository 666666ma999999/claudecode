---
name: fetch-bookmarks
description: influxプロジェクトのVNCコンテナ経由でX(Twitter)のブックマークを取得する。複数アカ対応（x_profiles/<account>）。教師データ変換を統合実行。Cookie更新は refresh-x-cookies スキル参照。
keywords: bookmark, ブックマーク, X, Twitter, 取得, fetch, scrape, 教師データ, style dataset, 複数アカウント
triggers:
  - ブックマーク取得
  - fetch bookmarks
  - Xのブックマーク
  - bookmark export
  - ブックマーク更新
allowed-tools: [Read, Glob, Grep, Bash]
---

# X Bookmark Fetch Skill

## When to use
- ユーザーがXのブックマークを取得/エクスポートしたい時
- ブックマーク教師データを更新したい時

## Not for
- 投稿エンゲージメントの実測取得 → `fetch-engagement`
- **Cookie更新** → influx側 `refresh-x-cookies` スキル（`~/Desktop/biz/influx/.claude/skills/refresh-x-cookies/SKILL.md`）

## Prerequisites
- influxプロジェクト: `~/Desktop/biz/influx`（INFLUX_ROOT環境変数 or デフォルト）
- Docker: `docker-compose.vnc.yml` が存在し `xstock-vnc` コンテナ起動可能
- **Cookie**: `x_profiles/<account>/cookies.json` が有効（account は `maaaki` or `kabuki666999`）（kabuki666999 は初回セットアップ未実施・2026-07 時点。使用前に influx の refresh-x-cookies skill で Cookie 作成が必要）

## Workflow

### Step 1: influxプロジェクト確認
```bash
INFLUX_ROOT="${INFLUX_ROOT:-$HOME/Desktop/biz/influx}"
ls "$INFLUX_ROOT/scripts/fetch_bookmarks.py" && echo "OK"
```

### Step 2: VNCコンテナ確認・起動
```bash
cd "$INFLUX_ROOT"
docker ps --filter name=xstock-vnc --format "{{.Status}}" | grep -q "^Up" || \
  docker compose -f docker-compose.vnc.yml up -d
```

### Step 3: Cookie有効性確認
```bash
# 使うアカウントの Cookie mtime 確認
ACCOUNT="maaaki"  # or kabuki666999
python3 -c "import os,time;p=f'$HOME/Desktop/biz/influx/x_profiles/$ACCOUNT/cookies.json';print(int((time.time()-os.path.getmtime(p))/86400),'days')"
```
（kabuki666999 は初回セットアップ未実施・2026-07 時点。使用前に influx の refresh-x-cookies skill で Cookie 作成が必要）

**Cookie期限切れ時** → **influx側 `refresh-x-cookies` スキル** 参照:
```bash
cd ~/Desktop/biz/influx
python3 scripts/import_chrome_cookies.py --chrome-profile "Default"   --account maaaki
python3 scripts/import_chrome_cookies.py --chrome-profile "Profile 2" --account kabuki666999
```

### Step 4: ブックマーク取得（複数アカ対応）

**make_article からのラッパー経由**:
```bash
cd ~/Desktop/biz/make_article
bash scripts/fetch_and_ingest.sh --account maaaki
# or
bash scripts/fetch_and_ingest.sh --account kabuki666999 --max-scrolls 10
```

**直接 influx で実行**:
```bash
cd "$INFLUX_ROOT"
docker exec xstock-vnc python scripts/fetch_bookmarks.py \
  --profile x_profiles/maaaki \
  --out /app/output/bookmarks.jsonl \
  --max-empty-batches 5 \
  --max-runtime-min 30
```

### Step 5: 結果確認
```bash
# 注意: Step 4 をラッパー経由で実行した場合の出力先は ~/Desktop/biz/make_article/data/bookmarks.jsonl（influx側 output/ は更新されない）
wc -l "$INFLUX_ROOT/output/bookmarks.jsonl"
head -3 "$INFLUX_ROOT/output/bookmarks.jsonl" | python3 -c "
import sys,json
for l in sys.stdin:
    d=json.loads(l)
    print(f'  @{d.get(\"author\",\"?\"):15s} {d.get(\"text\",\"\")[:50]}')
"
```

### Step 6: 教師データ変換（オプション）
```bash
# 生データをコピー（tier3_posting は autopost へ移設済み・autopost 側が現行）
AUTOPOST_ROOT="$HOME/Desktop/biz/autopost"
cp "$INFLUX_ROOT/output/bookmarks.jsonl" "$AUTOPOST_ROOT/data/writing_style/bookmarks/raw/x_bookmarks.jsonl"

# 正規化・ラベリング
cd "$AUTOPOST_ROOT"
python3 -m tier3_posting.cli.build_style_dataset

# LLM補助ラベリング付き
python3 -m tier3_posting.cli.build_style_dataset --use-llm
```

## Failure handling
- **Cookie期限切れ** → influx側 `refresh-x-cookies` スキル参照（1コマンドで完結）
- **Cookie未セットアップ** → `python3 scripts/import_chrome_cookies.py --chrome-profile <profile> --account <account>`
- **VNCコンテナ未起動** → `cd ~/Desktop/biz/influx && docker compose -f docker-compose.vnc.yml up -d`
- **DOM selector変化でentryが取れない** → `fetch_bookmarks.py` の GraphQL URL パターン確認

## Output
- 生データ: `output/bookmarks.jsonl` (JSONL形式)
- 教師データ: `~/Desktop/biz/autopost/data/writing_style/bookmarks/normalized.jsonl` (ラベル付きJSONL・influx側の同パスは2026-04で停止した旧世代)

## 関連ファイル
- ラッパー: `~/Desktop/biz/make_article/scripts/fetch_and_ingest.sh`
- 本体テンプレ: `~/Desktop/biz/make_article/scripts/fetch_bookmarks_for_influx.py`（influxへコピーして使用）
- **Cookie管理**: `~/Desktop/biz/influx/.claude/skills/refresh-x-cookies/SKILL.md`（Canonical）
- **抽出スクリプト**: `~/Desktop/biz/influx/scripts/import_chrome_cookies.py`
