---
name: x-scraping
description: |
  X(Twitter)からツイートを安全に収集するスキル。bot検知を回避しながらPlaywrightでスクレイピングを実行。
  Cookieベース認証、人間らしい操作パターン、いいね数フィルタリングに対応。
  キーワード: X, Twitter, スクレイピング, ツイート収集, インフルエンサー
compatibility: "requires: Playwright, Python 3.x, X(Twitter) cookies"
metadata:
  author: masaaki-nagasawa
  version: 1.0.0
---

# X (Twitter) スクレイピングスキル

## 使用タイミング

以下のリクエストで発動:
- 「Xからツイートを収集」
- 「Twitterスクレイピング」
- 「インフルエンサーの投稿を取得」
- 「X収集システムを構築」

## 重要な制約

### Xのbot検知対策
1. **Playwrightで直接ログイン不可** - ユーザー名入力時点でブロックされる
2. **必ず手動ログイン後のCookie利用** - リモートChromeデバッグ経由で取得
3. **週1-2回程度の使用推奨** - 頻繁なアクセスはアカウント凍結リスク

### 技術的制約
- X APIは有料（月額$100〜）のため、ブラウザ自動化を採用
- 通知メール経由ではいいね数を取得できない
- Nitterミラーは多くが機能停止

## セットアップ手順

### 1. プロジェクト構成

```
project/
├── collector/
│   ├── __init__.py
│   ├── config.py        # インフルエンサー設定、検索URL
│   ├── x_collector.py   # メイン収集クラス
│   └── classifier.py    # ツイート分類（オプション）
├── scripts/
│   └── collect_tweets.py
├── x_profile/
│   └── cookies.json     # 認証Cookie
├── output/              # 収集結果
├── requirements.txt
└── venv/
```

### 2. 依存パッケージ

```
# requirements.txt
playwright==1.57.0
python-dateutil>=2.8.2
```

### 3. Cookie取得手順（重要）

**すべてのChromeを終了してから実行：**

```bash
# 1. Chrome終了確認
pkill -9 Chrome
pgrep Chrome  # 何も表示されなければOK

# 2. デバッグモードでChrome起動
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --remote-debugging-port=9222 --user-data-dir=/tmp/chrome-debug-profile &

# 3. 接続確認（JSON応答があればOK）
curl -s http://localhost:9222/json/version

# 4. 開いたChromeで https://twitter.com にログイン

# 5. PythonでCookie取得
python -c "
from playwright.sync_api import sync_playwright
from pathlib import Path
import json

profile_path = Path('x_profile')
profile_path.mkdir(parents=True, exist_ok=True)

with sync_playwright() as p:
    browser = p.chromium.connect_over_cdp('http://localhost:9222')
    context = browser.contexts[0]
    cookies = context.cookies()
    x_cookies = [c for c in cookies if 'twitter.com' in c.get('domain', '') or 'x.com' in c.get('domain', '')]

    cookie_file = profile_path / 'cookies.json'
    with open(cookie_file, 'w') as f:
        json.dump(x_cookies, f, indent=2)

    auth = next((c for c in x_cookies if c['name'] == 'auth_token'), None)
    print(f'Cookie保存: {len(x_cookies)}個, 認証トークン: {\"あり\" if auth else \"なし\"}')
    browser.close()
"
```

## コア実装

### config.py テンプレート

```python
from pathlib import Path

PROJECT_ROOT = Path(__file__).parent.parent
PROFILE_PATH = PROJECT_ROOT / "x_profile"
OUTPUT_DIR = PROJECT_ROOT / "output"

# インフルエンサーグループ設定
INFLUENCER_GROUPS = {
    "group1": {
        "name": "主要インフルエンサー",
        "accounts": ["user1", "user2", "user3"],
        "min_faves": 500,  # いいね閾値
        "is_contrarian": False,
    },
    "group2": {
        "name": "逆指標",
        "accounts": ["contrarian_user"],
        "min_faves": 50,
        "is_contrarian": True,  # 逆指標フラグ
    },
}

# 検索URL生成（min_faves:N でいいね数フィルタ）
def generate_search_url(accounts: list, min_faves: int) -> str:
    users = " OR ".join([f"from:{u}" for u in accounts])
    query = f"min_faves:{min_faves} ({users})"
    from urllib.parse import quote
    return f"https://twitter.com/search?q={quote(query)}&f=live"

SEARCH_URLS = {
    key: generate_search_url(info["accounts"], info["min_faves"])
    for key, info in INFLUENCER_GROUPS.items()
}

# 収集設定（人間らしい動作）
COLLECTION_SETTINGS = {
    "max_scrolls": 10,
    "min_wait_sec": 2,
    "max_wait_sec": 5,
    "scroll_min": 300,
    "scroll_max": 600,
    "reading_probability": 0.3,
    "reading_min_sec": 3,
    "reading_max_sec": 8,
}
```

### x_collector.py 主要部分

```python
from playwright.sync_api import sync_playwright, Page
import time
import random
import json
import re
from pathlib import Path
from typing import List, Dict, Optional
from datetime import datetime

class SafeXCollector:
    def __init__(self, profile_path: str):
        self.profile_path = Path(profile_path).resolve()
        self.tweets = []
        self.collected_urls = set()

    def _load_cookies(self) -> List[Dict]:
        cookie_file = self.profile_path / "cookies.json"
        if cookie_file.exists():
            with open(cookie_file, 'r') as f:
                return json.load(f)
        return []

    def collect(self, search_url: str, max_scrolls: int = 10) -> List[Dict]:
        cookies = self._load_cookies()
        if not cookies:
            print("[エラー] Cookieがありません。セットアップを実行してください。")
            return []

        with sync_playwright() as p:
            browser = p.chromium.launch(headless=False)
            context = browser.new_context(
                viewport={"width": 1280, "height": 900},
                locale="ja-JP",
                timezone_id="Asia/Tokyo",
            )
            context.add_cookies(cookies)

            try:
                page = context.new_page()
                page.goto(search_url, wait_until="domcontentloaded")
                self._human_wait(3, 5)

                if not self._check_login(page):
                    print("[エラー] ログインしていません")
                    return []

                for i in range(max_scrolls):
                    new_count = self._collect_visible_tweets(page)
                    print(f"スクロール {i+1}/{max_scrolls} (+{new_count}件)")

                    if i < max_scrolls - 1:
                        self._human_scroll(page)
                        self._human_wait(2, 5)
            finally:
                context.close()
                browser.close()

        return self.tweets

    def _check_login(self, page: Page) -> bool:
        try:
            page.wait_for_selector(
                '[data-testid="SideNav_AccountSwitcher_Button"]',
                timeout=5000
            )
            return True
        except:
            return False

    def _human_wait(self, min_sec: float, max_sec: float):
        time.sleep(random.uniform(min_sec, max_sec))

    def _human_scroll(self, page: Page):
        scroll = random.randint(300, 600)
        for _ in range(random.randint(3, 6)):
            page.mouse.wheel(0, scroll // 5)
            time.sleep(random.uniform(0.1, 0.3))

    def _collect_visible_tweets(self, page: Page) -> int:
        new_count = 0
        for card in page.query_selector_all('[data-testid="tweet"]'):
            data = self._parse_tweet(card)
            if data and data['url'] not in self.collected_urls:
                self.tweets.append(data)
                self.collected_urls.add(data['url'])
                new_count += 1
        return new_count

    def _parse_tweet(self, card) -> Optional[Dict]:
        try:
            # ユーザー名
            user_elem = card.query_selector('[data-testid="User-Name"]')
            username_text = user_elem.inner_text() if user_elem else ""
            match = re.search(r'@(\w+)', username_text)
            username = match.group(1) if match else ""

            # 本文
            text_elem = card.query_selector('[data-testid="tweetText"]')
            text = text_elem.inner_text() if text_elem else ""

            # URL
            for link in card.query_selector_all('a[href*="/status/"]'):
                href = link.get_attribute('href')
                if href and '/status/' in href:
                    url = f"https://twitter.com{href}" if href.startswith('/') else href
                    break
            else:
                return None

            # 投稿時間
            time_elem = card.query_selector('time')
            posted_at = time_elem.get_attribute('datetime') if time_elem else None

            # いいね数
            like_elem = card.query_selector('[data-testid="like"] span span')
            like_count = self._parse_count(like_elem.inner_text()) if like_elem else None

            return {
                'username': username,
                'text': text,
                'url': url,
                'posted_at': posted_at,
                'like_count': like_count,
                'collected_at': datetime.now().isoformat()
            }
        except:
            return None

    def _parse_count(self, text: str) -> Optional[int]:
        if not text:
            return None
        text = text.strip().upper()
        try:
            if 'K' in text:
                return int(float(text.replace('K', '')) * 1000)
            elif 'M' in text:
                return int(float(text.replace('M', '')) * 1000000)
            return int(text.replace(',', ''))
        except:
            return None
```

## トラブルシューティング

### Cookie取得時の問題

| 症状 | 原因 | 解決策 |
|------|------|--------|
| 「Chromeに接続できません」 | デバッグポート未起動 | 全Chrome終了後、--remote-debugging-port=9222で起動 |
| 認証トークンなし | ログイン未完了 | Chrome内でX.comにログイン完了後に取得 |
| ポート確認でJSON空 | 通常Chromeが残存 | `pkill -9 Chrome`で強制終了してから再起動 |
| **Googleアカウントにアクセスできない** | デバッグChrome起動中 | 下記「通常Chromeへの復帰」参照 |

### 通常Chromeへの復帰（重要）

デバッグChromeは一時プロファイル（`/tmp/chrome-debug`）を使用するため、**Googleアカウントや普段のブックマークは使えない**。

**症状:**
- Googleにログインできない
- ブックマークがない
- 「安全でないブラウザ」エラー

**復帰手順:**
```bash
# 1. デバッグChromeを終了
pkill -9 Chrome

# 2. 確認
pgrep Chrome  # 何も出なければOK

# 3. Dockから通常のChromeを起動
```

**作業フロー（推奨）:**
```
Cookie取得作業:
  pkill Chrome → デバッグChrome起動 → Xログイン → Cookie取得 → pkill Chrome

通常利用に戻る:
  Dockから通常Chrome起動
```

### 収集時の問題

| 症状 | 原因 | 解決策 |
|------|------|--------|
| ログイン確認失敗 | Cookie期限切れ | 再度Cookie取得手順を実行 |
| ツイート0件 | セレクタ変更 | data-testid属性を確認・更新 |
| アカウント凍結 | 過剰アクセス | 週1-2回に頻度を下げる |

### Chrome起動コマンド（OS別）

```bash
# macOS
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --remote-debugging-port=9222 --user-data-dir=/tmp/chrome-debug &

# Linux
google-chrome --remote-debugging-port=9222 --user-data-dir=/tmp/chrome-debug &

# Windows
"C:\Program Files\Google\Chrome\Application\chrome.exe" --remote-debugging-port=9222 --user-data-dir=%TEMP%\chrome-debug
```

## 実行例

```bash
# 環境準備
cd /path/to/project
source venv/bin/activate

# 収集実行
python scripts/collect_tweets.py --groups group1 --scrolls 5

# 全グループ収集
python scripts/collect_tweets.py --scrolls 10
```

## 環境選択: ローカル vs Docker

### 結論: ローカル実行を推奨

| 環境 | 評価 | 理由 |
|------|------|------|
| **ローカル (venv)** | ✅ 推奨 | セットアップ簡単、CDP接続可能、デバッグ容易 |
| Docker + VNC | ❌ 非推奨 | 設定複雑、接続不安定、トラブル多発 |
| Docker headless | △ 条件付き | bot検知されやすい、事前Cookie取得必須 |

### Docker + VNC で遭遇した問題

- VNC接続後に画面が表示されない
- noVNCのパス変更でスクリプト修正が必要
- X11転送設定が複雑（macOS + XQuartz）

**→ 詳細は `playwright-browser-automation` スキルの「Docker + VNC でのGUI実行は不安定」を参照**

## Cookie有効期限の管理

### XのCookie有効期間

約数週間〜数ヶ月（変動あり）

### 再取得が必要なタイミング

- 収集スクリプトで「ログインしていません」エラー
- 認証トークン（auth_token）が期限切れ

### 推奨フロー

```
収集実行
  ↓
ログイン確認失敗？
  ↓ Yes
Cookie再取得（CDP接続で手動ログイン）
  ↓
再実行
```

**→ 詳細は `playwright-browser-automation` スキルの「Cookie有効期限の管理パターン」を参照**

## 参考: 検索URL構文

```
min_faves:500                    # いいね500以上
from:username                    # 特定ユーザー
(from:user1 OR from:user2)       # 複数ユーザー
min_faves:100 from:user          # 組み合わせ
since:2026-01-27                 # 開始日（この日以降）
until:2026-01-29                 # 終了日（この日未満）
&f=live                          # 最新順
```

### 日付フィルタの注意点

- `since:YYYY-MM-DD` と `until:YYYY-MM-DD` で期間指定
- `until` は**その日を含まない**ため、1/27-1/28を取得するには `until:2026-01-29` が必要
- URLエンコード例: `since%3A2026-01-27%20until%3A2026-01-29`

## 動的終了判定パターン

### 概要

スクロール回数を固定せず、「新規ツイート0件がN回連続」で終了する方式。
効率的かつ取りこぼしを防ぐ。

### 実装例（Python）

```python
consecutive_empty = 0
stop_after_empty = 3  # 3回連続で終了

for i in range(max_scrolls):
    new_count = self._collect_visible_tweets(page)

    if new_count == 0:
        consecutive_empty += 1
        if consecutive_empty >= stop_after_empty:
            print(f"新規0件が{stop_after_empty}回連続のため終了")
            break
    else:
        consecutive_empty = 0  # リセット

    self._human_scroll(page)
    self._human_wait(2, 5)
```

### 実装例（Playwright MCP JavaScript）

Playwright MCPの`browser_run_code`で使用可能なJavaScriptパターン:

```javascript
async (page) => {
  const allTweets = [];
  const seenUrls = new Set();

  const maxScrolls = 50;
  const stopAfterEmpty = 3;
  let consecutiveEmpty = 0;

  for (let scrollCount = 0; scrollCount < maxScrolls; scrollCount++) {
    const prevCount = allTweets.length;

    const cards = await page.$$('[data-testid="tweet"]');

    for (const card of cards) {
      try {
        // ユーザー名
        const userElem = await card.$('[data-testid="User-Name"]');
        const usernameText = userElem ? await userElem.innerText() : '';
        const usernameMatch = usernameText.match(/@(\w+)/);
        const username = usernameMatch ? usernameMatch[1] : '';

        // 本文
        const textElem = await card.$('[data-testid="tweetText"]');
        const text = textElem ? await textElem.innerText() : '';

        // URL
        const links = await card.$$('a[href*="/status/"]');
        let url = '';
        for (const link of links) {
          const href = await link.getAttribute('href');
          if (href && href.includes('/status/')) {
            url = href.startsWith('/') ? `https://x.com${href}` : href;
            break;
          }
        }

        if (!url || seenUrls.has(url)) continue;
        seenUrls.add(url);

        // 投稿時間
        const timeElem = await card.$('time');
        const postedAt = timeElem ? await timeElem.getAttribute('datetime') : null;

        // いいね数（K/M対応）
        const likeElem = await card.$('[data-testid="like"] span span');
        const likeText = likeElem ? await likeElem.innerText() : '';
        let likes = null;
        if (likeText) {
          const upper = likeText.trim().toUpperCase();
          if (upper.includes('K')) likes = Math.round(parseFloat(upper.replace('K', '')) * 1000);
          else if (upper.includes('M')) likes = Math.round(parseFloat(upper.replace('M', '')) * 1000000);
          else likes = parseInt(upper.replace(/,/g, '')) || null;
        }

        allTweets.push({ username, text, url, posted_at: postedAt, likes });
      } catch (e) {}
    }

    // 動的終了判定
    const newCount = allTweets.length - prevCount;
    if (newCount === 0) {
      consecutiveEmpty++;
      if (consecutiveEmpty >= stopAfterEmpty) {
        return { total: allTweets.length, tweets: allTweets, reason: '3回連続空で終了' };
      }
    } else {
      consecutiveEmpty = 0;
    }

    await page.mouse.wheel(0, 800);
    await page.waitForTimeout(1500);
  }

  return { total: allTweets.length, tweets: allTweets, reason: '最大スクロール到達' };
}
```

### maxScrollsの目安（実績ベース）

2日間（since/until）の収集における実績値:

| グループ | アカウント数 | min_faves | ツイート数 | 必要スクロール | 推奨maxScrolls |
|----------|-------------|-----------|------------|----------------|----------------|
| 7名 | 100 | 25件 | ~20回 | 30 |
| 22名 | 72 | 161件 | 126回 | **130以上** |
| 1名 | 50 | 15件 | ~10回 | 20 |

**重要**: アカウント数が多く min_faves が低いグループ（22名/72いいね等）は、100回以上のスクロールが必要になる場合がある。maxScrollsが不足すると動的終了条件が発動せず、ツイートを取りこぼす。

推奨アプローチ:
1. まず maxScrolls=50 で試す
2. 「最大スクロール到達」で終了した場合 → maxScrolls を段階的に増やす（70→100→130）
3. 「3回連続空で終了」になるまで繰り返す

### Playwright MCP での注意事項

| 問題 | 原因 | 解決策 |
|------|------|--------|
| `ReferenceError: setTimeout is not defined` | Playwright MCP環境ではNode.jsのsetTimeoutが使えない | `page.waitForTimeout(ms)` を使用 |

```javascript
// NG: setTimeout は使えない
await new Promise(r => setTimeout(r, 2000));

// OK: page.waitForTimeout を使用
await page.waitForTimeout(2000 + Math.floor(Math.random() * 1500));
```

### min_faves閾値の調整

| 状況 | 対応 |
|------|------|
| 取得件数が少ない | min_favesを下げる（502→100など） |
| ノイズが多い | min_favesを上げる |
| 特定期間のみ取得 | since/untilで日付フィルタ追加 |

## LLM分類（Claude API）

### 概要

キーワードベース分類に加え、Claude API（Haiku）を使ったLLM分類機能を実装済み。

### ファイル構成

| ファイル | 役割 |
|---------|------|
| `collector/llm_classifier.py` | LLM分類器本体（urllib.requestで依存追加なし） |
| `data/few_shot_examples.json` | Few-shot例（24件、7カテゴリ+該当なし+複数カテゴリ） |
| `scripts/classify_tweets.py` | 分類実行スクリプト（キーワード/LLM比較、viewer.html再生成） |
| `collector/config.py` の `LLM_CONFIG` | モデル名、バッチサイズ等の設定 |

### 実行方法

```bash
# ANTHROPIC_API_KEY環境変数を設定
export ANTHROPIC_API_KEY=sk-ant-...

# 最新のツイートJSONを自動検出して分類
python scripts/classify_tweets.py

# 入力ファイル指定
python scripts/classify_tweets.py --input output/tweets_YYYYMMDD_HHMMSS.json

# viewer.html再生成をスキップ
python scripts/classify_tweets.py --no-viewer
```

### 精度改善

- `data/few_shot_examples.json` に誤分類例を追加してリラン
- viewer.htmlにカテゴリフィルタタブあり（LLM/キーワード両方の分類バッジ表示）
- 逆指標アカウント（is_contrarian=true）の強気ツイート → warning_signalsに自動分類

## 関連ガイド
- ツール選択基準: `~/.claude/rules/web-scraping.md` を参照
