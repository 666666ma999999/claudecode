from playwright.sync_api import sync_playwright
import time, os

def main():
    screenshots_dir = "/Users/masaaki_nagasawa/.claude/mercari_screenshots"
    os.makedirs(screenshots_dir, exist_ok=True)

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=False, slow_mo=300)
        context = browser.new_context(
            viewport={"width": 1280, "height": 800},
            locale="ja-JP",
            timezone_id="Asia/Tokyo"
        )
        page = context.new_page()

        try:
            print("Step 1: トップページアクセス...")
            page.goto("https://jp.mercari.com/", wait_until="domcontentloaded", timeout=60000)
            time.sleep(1)

            login_btn = page.locator('button:has-text("ログイン"), a:has-text("ログイン")')
            if login_btn.count() > 0:
                login_btn.first.click()
            time.sleep(2)

            print("Step 2: メールアドレス入力...")
            page.wait_for_load_state("domcontentloaded")
            email_input = page.locator('input').first
            email_input.fill("100ameros@gmail.com")
            time.sleep(0.5)

            next_btn = page.locator('button:has-text("次へ"), button[type="submit"]')
            next_btn.first.click()
            time.sleep(2)

            print("Step 3: パスワード入力...")
            pass_input = page.locator('input[type="password"]')
            pass_input.wait_for(state="visible", timeout=10000)
            pass_input.fill("carrY-0011")
            time.sleep(0.5)

            submit_btn = page.locator('button:has-text("次へ"), button:has-text("ログイン"), button[type="submit"]')
            submit_btn.first.click()
            time.sleep(3)

            print("Step 4: 認証コード入力...")
            page.screenshot(path=f"{screenshots_dir}/retry_01_2fa_page.png")

            code_input = page.locator('input[placeholder*="認証"], input[name*="code"], input[name*="otp"], input[type="tel"], input[type="number"], input[inputmode="numeric"]')
            if code_input.count() == 0:
                code_input = page.locator('input[type="text"]')

            code_input.first.wait_for(state="visible", timeout=15000)
            code_input.first.fill("827140")
            time.sleep(0.5)
            page.screenshot(path=f"{screenshots_dir}/retry_02_code_entered.png")

            verify_btn = page.locator('button:has-text("認証"), button:has-text("完了"), button[type="submit"]')
            verify_btn.first.click()
            print("認証ボタンクリック完了...")
            time.sleep(5)

            page.screenshot(path=f"{screenshots_dir}/retry_03_after_verify.png")

            current_url = page.url
            print(f"現在のURL: {current_url}")
            page.screenshot(path=f"{screenshots_dir}/retry_04_final.png", full_page=True)

            error_msg = page.locator('text=正しくありません, text=エラー, text=失敗')
            if error_msg.count() > 0:
                print(f"認証失敗: {error_msg.first.text_content()}")
            else:
                print("認証成功！")
                context.storage_state(path="/Users/masaaki_nagasawa/.claude/mercari_auth_state.json")
                print("認証状態を保存しました")

            time.sleep(30)

        except Exception as e:
            print(f"エラー: {e}")
            page.screenshot(path=f"{screenshots_dir}/retry_error.png")
            raise
        finally:
            context.close()
            browser.close()

if __name__ == "__main__":
    main()
