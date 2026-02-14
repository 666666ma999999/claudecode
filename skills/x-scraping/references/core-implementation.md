# コア実装

## config.py テンプレート

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

## x_collector.py 主要部分

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
