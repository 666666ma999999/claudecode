# セットアップガイド

## 依存パッケージ

```
# requirements.txt
playwright==1.57.0
python-dateutil>=2.8.2
```

## Cookie取得手順（重要）

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
