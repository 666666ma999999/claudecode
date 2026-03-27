---
name: fetch-bookmarks
description: influxプロジェクトのVNCコンテナ経由でX(Twitter)のブックマークを取得する。ブックマーク取得、Cookie再取得、教師データ変換を統合実行。任意のプロジェクトから呼び出し可能。
keywords: bookmark, ブックマーク, X, Twitter, 取得, fetch, scrape, 教師データ, style dataset
triggers:
  - ブックマーク取得
  - fetch bookmarks
  - Xのブックマーク
  - bookmark export
  - ブックマーク更新
---

# X Bookmark Fetch Skill

## When to use
- ユーザーがXのブックマークを取得/エクスポートしたい時
- ブックマーク教師データを更新したい時
- Cookie期限切れでブックマーク取得できない時

## Prerequisites
- influxプロジェクト: `~/Desktop/prm/influx`（INFLUX_ROOT環境変数 or デフォルト）
- Docker: `docker-compose.vnc.yml` が存在すること
- VNCコンテナ `xstock-vnc` が起動していること
- `x_profile/cookies.json` が有効であること

## Workflow

### Step 1: influxプロジェクト確認
```bash
INFLUX_ROOT="${INFLUX_ROOT:-$HOME/Desktop/prm/influx}"
ls "$INFLUX_ROOT/scripts/fetch_bookmarks.py" && echo "OK"
```

### Step 2: VNCコンテナ確認・起動
```bash
cd "$INFLUX_ROOT"
docker ps --filter name=xstock-vnc --format "{{.Status}}" || \
  docker compose -f docker-compose.vnc.yml up -d
```

### Step 3: Cookie有効性確認
```bash
docker exec xstock-vnc python -c "
from collector.cookie_crypto import load_cookies_encrypted
c = load_cookies_encrypted('./x_profile/cookies.json')
auth = [ck for ck in c if ck.get('name') in ('auth_token','ct0')]
print(f'Cookies: {len(c)}, Auth: {len(auth)}')
if len(auth) < 2: print('WARNING: Cookie expired')
"
```

Cookie期限切れの場合:
```bash
docker exec xstock-vnc rm -f /app/x_profile/SingletonLock /app/x_profile/SingletonCookie /app/x_profile/SingletonSocket
docker exec -d xstock-vnc python scripts/refresh_cookies_vnc.py --timeout 600
echo "http://localhost:6080 でVNCを開きXにログインしてください"
```

### Step 4: ブックマーク取得
```bash
# 出力先はユーザーに確認（デフォルト: influx内）
docker exec xstock-vnc python scripts/fetch_bookmarks.py \
  --out /app/output/bookmarks.jsonl \
  --max-empty-batches 5 \
  --max-runtime-min 30
```

別プロジェクトに直接出力する場合:
```bash
docker exec xstock-vnc python scripts/fetch_bookmarks.py \
  --out /app/output/bookmarks.jsonl
# ホスト側でコピー
cp "$INFLUX_ROOT/output/bookmarks.jsonl" "<destination_path>"
```

### Step 5: 結果確認
```bash
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
# 生データをコピー
cp "$INFLUX_ROOT/output/bookmarks.jsonl" "$INFLUX_ROOT/data/writing_style/bookmarks/raw/x_bookmarks.jsonl"

# 正規化・ラベリング
cd "$INFLUX_ROOT"
python3 extensions/tier3_posting/cli/build_style_dataset.py

# LLM補助ラベリング付き
python3 extensions/tier3_posting/cli/build_style_dataset.py --use-llm
```

## Failure handling
- Cookie期限切れ → Step 3のrefresh手順を案内
- VNCコンテナ未起動 → `docker compose -f docker-compose.vnc.yml up -d`
- SingletonLockエラー → `rm -f /app/x_profile/Singleton*`
- noVNCが開かない → `docker exec xstock-vnc ln -sf /usr/share/novnc/vnc.html /usr/share/novnc/index.html`

## Output
- 生データ: `output/bookmarks.jsonl` (JSONL形式)
- 教師データ: `data/writing_style/bookmarks/normalized.jsonl` (ラベル付きJSONL)
