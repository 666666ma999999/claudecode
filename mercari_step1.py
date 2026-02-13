"""Step 1: メルカリにログインし、2FA画面で停止する。ブラウザはCDP経由で接続可能な状態で維持。"""
from playwright.sync_api import sync_playwright
import time, os, signal, sys

def main():
    screenshots_dir = "/Users/masaaki_nagasawa/.claude/mercari_screenshots"
    os.makedirs(screenshots_dir, exist_ok=True)

    with sync_playwright() as p:
        browser = p.chromium.launch(
            headless=False,
            slow_mo=300,
            args=["--remote-debugging-port=9333"]
        )
        context = browser.new_context(
            viewport={"width": 1280, "height": 800},
            locale="ja-JP",
            timezone_id="Asia/Tokyo"
        )
        page = context.new_page()

        try:
            print("Step 1: トップページアクセス...")
            page.goto("https://jp.mercari.com/", wait_until="domcontentloaded", timeout=60000)
            time.sleep(2)

            login_btn = page.locator('button:has-text("ログイン"), a:has-text("ログイン")')
            if login_btn.count() > 0:
                login_btn.first.click()
            time.sleep(3)

            print("Step 2: メールアドレス入力...")
            page.wait_for_load_state("domcontentloaded")
            email_input = page.locator('input').first
            email_input.fill("100ameros@gmail.com")
            time.sleep(0.5)

            next_btn = page.locator('button:has-text("次へ"), button[type="submit"]')
            next_btn.first.click()
            time.sleep(3)

            print("Step 3: パスワード入力...")
            pass_input = page.locator('input[type="password"]')
            pass_input.wait_for(state="visible", timeout=10000)
            pass_input.fill("carrY-0011")
            time.sleep(0.5)

            submit_btn = page.locator('button:has-text("次へ"), button:has-text("ログイン"), button[type="submit"]')
            submit_btn.first.click()
            time.sleep(4)

            page.screenshot(path=f"{screenshots_dir}/step1_2fa_waiting.png")
            print("=" * 50)
            print("2FA画面に到達しました。SMSの認証コードを待っています。")
            print("ブラウザは開いたまま維持しています。")
            print("認証コードが届いたらStep2スクリプトで入力します。")
            print("=" * 50)

            # ブラウザを開いたまま無限待機（600秒=10分）
            time.sleep(600)

        except Exception as e:
            print(f"エラー: {e}")
            page.screenshot(path=f"{screenshots_dir}/step1_error.png")
            raise
        finally:
            context.close()
            browser.close()

if __name__ == "__main__":
    main()
