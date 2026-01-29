#!/usr/bin/env python3
"""
X認証Cookie取得スクリプト

使用方法:
1. 全てのChromeを終了
2. デバッグモードでChrome起動:
   "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --remote-debugging-port=9222 --user-data-dir=/tmp/chrome-debug &
3. ChromeでXにログイン
4. このスクリプトを実行
"""

import sys
import json
from pathlib import Path

try:
    from playwright.sync_api import sync_playwright
except ImportError:
    print("playwright未インストール: pip install playwright")
    sys.exit(1)


def get_cookies(output_dir: str = "x_profile", port: int = 9222):
    """リモートChromeからCookieを取得して保存"""

    profile_path = Path(output_dir)
    profile_path.mkdir(parents=True, exist_ok=True)

    print(f"Chrome (localhost:{port}) に接続中...")

    try:
        with sync_playwright() as p:
            browser = p.chromium.connect_over_cdp(f"http://localhost:{port}")
            contexts = browser.contexts

            if not contexts:
                print("[エラー] ブラウザコンテキストがありません")
                return False

            context = contexts[0]
            cookies = context.cookies()

            # X関連のCookieのみ抽出
            x_cookies = [
                c for c in cookies
                if 'twitter.com' in c.get('domain', '') or 'x.com' in c.get('domain', '')
            ]

            print(f"取得したCookie: {len(x_cookies)}個")

            # 認証トークン確認
            auth_token = next((c for c in x_cookies if c['name'] == 'auth_token'), None)

            if auth_token:
                print("[OK] 認証トークンを確認")
            else:
                print("[警告] 認証トークンなし - Xにログインしてください")
                return False

            # 保存
            cookie_file = profile_path / "cookies.json"
            with open(cookie_file, 'w') as f:
                json.dump(x_cookies, f, indent=2)

            print(f"保存先: {cookie_file}")
            browser.close()
            return True

    except Exception as e:
        if "connect" in str(e).lower():
            print(f"""
[エラー] Chromeに接続できません

確認事項:
1. 全てのChromeを終了したか
2. デバッグモードでChromeを起動したか

起動コマンド:
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --remote-debugging-port={port} --user-data-dir=/tmp/chrome-debug &

接続確認:
curl -s http://localhost:{port}/json/version
""")
        else:
            print(f"[エラー] {e}")
        return False


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="X認証Cookie取得")
    parser.add_argument("--output", "-o", default="x_profile", help="出力ディレクトリ")
    parser.add_argument("--port", "-p", type=int, default=9222, help="Chromeデバッグポート")
    args = parser.parse_args()

    success = get_cookies(args.output, args.port)
    sys.exit(0 if success else 1)
