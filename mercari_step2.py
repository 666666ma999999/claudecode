"""Step 2: Step1で開いたブラウザにCDP接続し、認証コードを入力する。"""
from playwright.sync_api import sync_playwright
import time, os, sys

def main():
    if len(sys.argv) < 2:
        print("使い方: python3 mercari_step2.py <認証コード>")
        sys.exit(1)

    code = sys.argv[1]
    screenshots_dir = "/Users/masaaki_nagasawa/.claude/mercari_screenshots"

    with sync_playwright() as p:
        # Step1で起動したブラウザにCDP接続
        print(f"ブラウザに接続中...")
        browser = p.chromium.connect_over_cdp("http://localhost:9333")

        contexts = browser.contexts
        if not contexts:
            print("エラー: ブラウザコンテキストが見つかりません")
            sys.exit(1)

        context = contexts[0]
        pages = context.pages
        if not pages:
            print("エラー: ページが見つかりません")
            sys.exit(1)

        page = pages[0]
        print(f"現在のURL: {page.url}")

        try:
            # 認証コード入力
            print(f"認証コード {code} を入力中...")
            code_input = page.locator('input[placeholder*="認証"], input[name*="code"], input[name*="otp"], input[type="tel"], input[type="number"], input[inputmode="numeric"]')
            if code_input.count() == 0:
                code_input = page.locator('input[type="text"]')

            code_input.first.wait_for(state="visible", timeout=10000)
            code_input.first.fill(code)
            time.sleep(0.5)
            page.screenshot(path=f"{screenshots_dir}/step2_code_entered.png")

            # 認証ボタンクリック
            verify_btn = page.locator('button:has-text("認証"), button:has-text("完了"), button[type="submit"]')
            verify_btn.first.click()
            print("認証ボタンクリック完了...")
            time.sleep(5)

            page.screenshot(path=f"{screenshots_dir}/step2_after_verify.png")
            current_url = page.url
            print(f"現在のURL: {current_url}")

            # エラー確認
            error_msg = page.locator('text=正しくありません, text=エラー, text=失敗')
            if error_msg.count() > 0:
                print(f"認証失敗: {error_msg.first.text_content()}")
            else:
                print("認証成功！")
                context.storage_state(path="/Users/masaaki_nagasawa/.claude/mercari_auth_state.json")
                print("認証状態を mercari_auth_state.json に保存しました")

            page.screenshot(path=f"{screenshots_dir}/step2_final.png", full_page=True)

        except Exception as e:
            print(f"エラー: {e}")
            page.screenshot(path=f"{screenshots_dir}/step2_error.png")
            raise

if __name__ == "__main__":
    main()
