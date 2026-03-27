---
name: max-scroll-scrape
description: Playwrightで無限スクロールページからデータを最大限取得するスクレイピングパターン。逐次保存、checkpoint復元、stale自動停止、実行時間制限を提供。X(Twitter)ブックマーク、タイムライン、検索結果、ECサイト商品一覧など、仮想スクロールを持つ任意のページに適用可能。
keywords: scrape, スクレイピング, Playwright, scroll, 無限スクロール, 最大取得, データ収集, bookmark, タイムライン
triggers:
  - スクレイピングで最大取得
  - 無限スクロール
  - Playwrightでデータ収集
  - max scroll
  - 全件取得
  - スクロールで全部取る
---

# Max Scroll Scrape Pattern

Playwrightの無限スクロールページから最大限のデータを取得する汎用パターン。

## When to use
- 無限スクロール/仮想スクロールのページからデータを全件取得したい時
- 取得件数が事前にわからず、末尾まで取り切りたい時
- 長時間スクレイピングでクラッシュ耐性が必要な時

## Core Pattern

以下の5つの要素を組み合わせる:

### 1. スマート停止条件（固定回数ではなく複合条件）

```python
import time

max_scrolls = None           # 安全弁（Noneで無制限）
max_empty_batches = 5        # N回連続で新規0件なら停止
max_runtime_min = 30         # 最大実行時間（分）
start_time = time.time()

scroll_count = 0
stale_count = 0

while True:
    # 安全弁
    if max_scrolls and scroll_count >= max_scrolls:
        break

    # 実行時間制限
    if (time.time() - start_time) / 60.0 >= max_runtime_min:
        break

    # スクロール実行 + データ取得
    page.evaluate("window.scrollBy(0, window.innerHeight * 2)")
    scroll_count += 1

    # ... データ取得処理 ...

    # stale判定
    if new_items_count == 0:
        stale_count += 1
        if stale_count >= max_empty_batches:
            break  # 全件取得完了
    else:
        stale_count = 0
```

### 2. DOM変化を待つスクロール（固定sleepではなく）

```python
def wait_for_new_elements(page, selector, prev_count, timeout_sec=5.0):
    """スクロール後、要素数が増えるのを最大timeout_sec秒待つ。"""
    deadline = time.time() + timeout_sec
    while time.time() < deadline:
        current = page.locator(selector).count()
        if current > prev_count:
            return current
        time.sleep(0.5)
    return page.locator(selector).count()

# 使い方
prev_count = page.locator(ITEM_SELECTOR).count()
page.evaluate("window.scrollBy(0, window.innerHeight * 2)")
new_count = wait_for_new_elements(page, ITEM_SELECTOR, prev_count)
```

### 3. 逐次保存（クラッシュ耐性）

```python
import json
from pathlib import Path

out_path = Path("output.jsonl")
seen_urls = set()

# 追記モード: 既存ファイルからseen復元
if out_path.exists():
    with open(out_path, "r") as f:
        for line in f:
            d = json.loads(line.strip())
            if d.get("url"):
                seen_urls.add(d["url"])

out_file = open(out_path, "a", encoding="utf-8")

def save_item(item):
    if item["url"] not in seen_urls:
        seen_urls.add(item["url"])
        out_file.write(json.dumps(item, ensure_ascii=False) + "\n")
        out_file.flush()  # 即座にディスクへ
```

### 4. チェックポイント（再開可能）

```python
def save_checkpoint(path, seen_urls, total, scroll):
    with open(path, "w") as f:
        json.dump({
            "seen_urls": sorted(seen_urls),
            "total_count": total,
            "last_scroll": scroll,
            "last_updated": datetime.now().isoformat(),
        }, f, ensure_ascii=False, indent=2)

def load_checkpoint(path):
    if not Path(path).exists():
        return {"seen_urls": set(), "total_count": 0}
    with open(path) as f:
        data = json.load(f)
    return {"seen_urls": set(data.get("seen_urls", [])), "total_count": data.get("total_count", 0)}
```

### 5. DOM スクレイピング（仮想スクロール対応）

```python
def scrape_visible_items(page, item_selector, extract_fn):
    """現在表示されているアイテムをDOMから取得する。

    仮想スクロールでは画面外のDOMが消えるため、
    毎スクロール後に「今見えているもの」を全て取得し、
    seen_urlsで重複管理する。
    """
    items = page.locator(item_selector)
    results = []
    for i in range(items.count()):
        try:
            data = extract_fn(items.nth(i))
            if data:
                results.append(data)
        except Exception:
            continue
    return results
```

## 完全テンプレート

```python
#!/usr/bin/env python3
"""無限スクロールページからの最大データ取得テンプレート。"""

import json
import time
from datetime import datetime
from pathlib import Path
from playwright.sync_api import sync_playwright

# === 設定（ページごとにカスタマイズ） ===
TARGET_URL = "https://example.com/infinite-scroll-page"
ITEM_SELECTOR = '[data-testid="item"]'  # アイテムのCSSセレクタ
OUT_PATH = "output/items.jsonl"
CHECKPOINT_PATH = "output/checkpoint.json"
MAX_EMPTY_BATCHES = 5
MAX_RUNTIME_MIN = 30

def extract_item(element):
    """1アイテムからデータを抽出する（ページ固有の実装）。"""
    text = element.locator(".item-text").text_content() or ""
    url = element.locator("a").first.get_attribute("href") or ""
    return {"url": url, "text": text.strip()} if url else None

# === 汎用ロジック（変更不要） ===

def load_checkpoint(path):
    if not Path(path).exists():
        return {"seen_urls": set(), "total_count": 0}
    with open(path) as f:
        data = json.load(f)
    return {"seen_urls": set(data.get("seen_urls", [])), "total_count": data.get("total_count", 0)}

def save_checkpoint(path, seen, total, scroll):
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w") as f:
        json.dump({"seen_urls": sorted(seen), "total_count": total, "last_scroll": scroll, "last_updated": datetime.now().isoformat()}, f, ensure_ascii=False, indent=2)

def wait_for_new(page, selector, prev, timeout=5.0):
    deadline = time.time() + timeout
    while time.time() < deadline:
        cur = page.locator(selector).count()
        if cur > prev:
            return cur
        time.sleep(0.5)
    return page.locator(selector).count()

def run():
    cp = load_checkpoint(CHECKPOINT_PATH)
    seen = cp["seen_urls"]
    total = cp["total_count"]

    out = Path(OUT_PATH)
    out.parent.mkdir(parents=True, exist_ok=True)
    # 追記モードで既存URLも復元
    if out.exists():
        with open(out) as f:
            for l in f:
                d = json.loads(l.strip())
                if d.get("url"): seen.add(d["url"])
    f = open(out, "a", encoding="utf-8")

    with sync_playwright() as pw:
        browser = pw.chromium.launch(headless=False)
        page = browser.new_page(viewport={"width": 1280, "height": 900})
        page.goto(TARGET_URL, wait_until="domcontentloaded", timeout=60000)
        page.wait_for_selector(ITEM_SELECTOR, timeout=15000)

        start = time.time()
        scroll = stale = 0

        while True:
            if (time.time() - start) / 60 >= MAX_RUNTIME_MIN:
                break

            prev = page.locator(ITEM_SELECTOR).count()
            page.evaluate("window.scrollBy(0, window.innerHeight * 2)")
            scroll += 1
            wait_for_new(page, ITEM_SELECTOR, prev)

            items = page.locator(ITEM_SELECTOR)
            new_count = 0
            for i in range(items.count()):
                try:
                    data = extract_item(items.nth(i))
                    if data and data["url"] not in seen:
                        seen.add(data["url"])
                        f.write(json.dumps(data, ensure_ascii=False) + "\n")
                        f.flush()
                        total += 1
                        new_count += 1
                except Exception:
                    continue

            save_checkpoint(CHECKPOINT_PATH, seen, total, scroll)

            if new_count == 0:
                stale += 1
                if stale >= MAX_EMPTY_BATCHES:
                    break
            else:
                stale = 0

            print(f"scroll {scroll}: +{new_count} (total={total}, stale={stale}/{MAX_EMPTY_BATCHES})")

        browser.close()
    f.close()
    print(f"Done: {total} items in {(time.time()-start)/60:.1f}min")

if __name__ == "__main__":
    run()
```

## カスタマイズポイント

| 項目 | 変更箇所 | 例 |
|------|---------|---|
| 対象ページURL | `TARGET_URL` | X bookmarks, EC商品一覧 |
| アイテムセレクタ | `ITEM_SELECTOR` | `[data-testid="tweet"]`, `.product-card` |
| データ抽出 | `extract_item()` | テキスト、URL、価格、画像URL等 |
| 認証 | Cookie追加 or persistent context | `context.add_cookies(cookies)` |
| Service Worker対策 | `service_workers="block"` | X/Twitterで必要 |

## 実績

| サイト | アイテム | 取得件数 | 所要時間 |
|--------|---------|---------|---------|
| X ブックマーク | ツイート | 216件（全件） | 4.3分 |

## Xブックマーク専用コマンド

influxプロジェクト経由で実行:
```bash
cd ~/Desktop/prm/influx
docker exec xstock-vnc python scripts/fetch_bookmarks.py \
  --out /app/output/bookmarks.jsonl \
  --max-empty-batches 5 \
  --max-runtime-min 30 \
  --checkpoint /app/output/bookmarks_checkpoint.json
```

## Anti-pattern（やってはいけない）
- `--max-scrolls 50` のような固定回数 → 件数は人/ページによって違う
- `time.sleep(3)` 固定待機 → DOM変化を待つ方が速く正確
- 最後にまとめて保存 → クラッシュで全データ消失
- `networkidle` 待ち → X等のSPAでは永久にidle にならない
