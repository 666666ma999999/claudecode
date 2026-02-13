from playwright.sync_api import sync_playwright
import time
import os
import traceback


def main():
    screenshots_dir = "/Users/masaaki_nagasawa/.claude/mercari_screenshots"
    os.makedirs(screenshots_dir, exist_ok=True)

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=False, slow_mo=500)
        context = browser.new_context(
            viewport={"width": 1280, "height": 800},
            locale="ja-JP",
            timezone_id="Asia/Tokyo",
        )
        page = context.new_page()

        try:
            # Step 1: メルカリトップ→ログイン
            print("[Step 1] メルカリトップページへアクセス...")
            page.goto("https://jp.mercari.com/", wait_until="domcontentloaded", timeout=60000)
            time.sleep(2)

            login_btn = page.locator('button:has-text("ログイン"), a:has-text("ログイン")')
            if login_btn.count() > 0:
                print("  ログインボタンを検出、クリックします")
                login_btn.first.click()
            else:
                print("  ログインボタンが見つからないため、直接signinページへ遷移")
                page.goto("https://jp.mercari.com/signin", wait_until="domcontentloaded")

            time.sleep(3)
            page.screenshot(path=f"{screenshots_dir}/2fa_01_login_page.png")
            print(f"  スクリーンショット保存: 2fa_01_login_page.png")
            print(f"  現在のURL: {page.url}")

            # Step 2: メールアドレス入力
            print("[Step 2] メールアドレスを入力...")
            email_input = page.locator(
                'input[type="email"], input[name="email"], '
                'input[placeholder*="メール"], input[placeholder*="電話"]'
            )
            if email_input.count() == 0:
                print("  専用入力欄が見つからないため、テキスト入力欄を使用")
                email_input = page.locator('input[type="text"]').first
            else:
                email_input = email_input.first

            email_input.wait_for(state="visible", timeout=10000)
            email_input.fill("100ameros@gmail.com")
            time.sleep(1)

            next_btn = page.locator('button:has-text("次へ"), button[type="submit"]')
            if next_btn.count() > 0:
                next_btn.first.click()
                print("  「次へ」ボタンをクリック")
            else:
                print("  WARNING: 次へボタンが見つかりません")

            time.sleep(3)
            page.screenshot(path=f"{screenshots_dir}/2fa_02_after_email.png")
            print(f"  スクリーンショット保存: 2fa_02_after_email.png")
            print(f"  現在のURL: {page.url}")

            # Step 3: パスワード入力
            print("[Step 3] パスワードを入力...")
            pass_input = page.locator('input[type="password"]')
            try:
                pass_input.wait_for(state="visible", timeout=10000)
                pass_input.fill("carrY-0011")
                time.sleep(1)

                submit_btn = page.locator(
                    'button:has-text("次へ"), button:has-text("ログイン"), button[type="submit"]'
                )
                if submit_btn.count() > 0:
                    submit_btn.first.click()
                    print("  ログインボタンをクリック")
                else:
                    print("  WARNING: ログインボタンが見つかりません")

                time.sleep(5)
            except Exception as e:
                print(f"  パスワード入力で問題発生: {e}")
                page.screenshot(path=f"{screenshots_dir}/2fa_03_error.png")

            page.screenshot(path=f"{screenshots_dir}/2fa_03_after_password.png")
            print(f"  スクリーンショット保存: 2fa_03_after_password.png")
            print(f"  現在のURL: {page.url}")

            # Step 4: 2FA認証コード入力
            print("[Step 4] 2FA認証コードを入力...")
            code_input = page.locator(
                'input[placeholder*="認証"], input[name*="code"], '
                'input[name*="otp"], input[type="tel"], '
                'input[type="number"], input[inputmode="numeric"]'
            )

            if code_input.count() == 0:
                print("  専用入力欄が見つからないため、テキスト入力欄を探索")
                code_input = page.locator('input[type="text"]')

            if code_input.count() == 0:
                print("  ERROR: 認証コード入力欄が見つかりません")
                page.screenshot(path=f"{screenshots_dir}/2fa_04_no_input.png")
                print("  ページの内容を確認してください")
                # ページのテキストを出力して状況把握
                body_text = page.locator("body").inner_text()
                print(f"  ページテキスト(先頭500文字): {body_text[:500]}")
                time.sleep(30)
                return

            try:
                code_input.first.wait_for(state="visible", timeout=15000)
                code_input.first.fill("496480")
                print("  認証コード 496480 を入力しました")
                time.sleep(1)
                page.screenshot(path=f"{screenshots_dir}/2fa_04_code_entered.png")
                print(f"  スクリーンショット保存: 2fa_04_code_entered.png")
            except Exception as e:
                print(f"  認証コード入力で問題発生: {e}")
                page.screenshot(path=f"{screenshots_dir}/2fa_04_error.png")
                body_text = page.locator("body").inner_text()
                print(f"  ページテキスト(先頭500文字): {body_text[:500]}")
                time.sleep(30)
                return

            # 認証ボタンクリック
            verify_btn = page.locator(
                'button:has-text("認証"), button:has-text("完了"), '
                'button:has-text("確認"), button[type="submit"]'
            )
            if verify_btn.count() > 0:
                verify_btn.first.click()
                print("  認証ボタンをクリック")
            else:
                print("  WARNING: 認証ボタンが見つかりません。Enterキーで送信を試みます")
                code_input.first.press("Enter")

            time.sleep(5)
            page.screenshot(path=f"{screenshots_dir}/2fa_05_after_verify.png")
            print(f"  スクリーンショット保存: 2fa_05_after_verify.png")
            print(f"  現在のURL: {page.url}")

            # エラーメッセージチェック（認証コード期限切れなど）
            error_text = page.locator(
                '[class*="error"], [class*="Error"], [role="alert"], '
                '[class*="warning"], [class*="Warning"]'
            )
            if error_text.count() > 0:
                for i in range(error_text.count()):
                    msg = error_text.nth(i).inner_text()
                    if msg.strip():
                        print(f"  エラー検出: {msg.strip()}")

            # ページ内に「期限切れ」「有効期限」などのテキストがあるかチェック
            body_text = page.locator("body").inner_text()
            if "期限" in body_text or "expired" in body_text.lower() or "無効" in body_text:
                print("  WARNING: 認証コードが期限切れまたは無効の可能性があります")
                print(f"  ページテキスト(先頭500文字): {body_text[:500]}")

            # Step 5: ログイン成功確認
            print("[Step 5] ログイン結果を確認...")
            current_url = page.url
            print(f"  最終URL: {current_url}")

            page.screenshot(path=f"{screenshots_dir}/2fa_06_final.png", full_page=True)
            print(f"  スクリーンショット保存: 2fa_06_final.png")

            # ログイン成功判定
            if "signin" not in current_url and "login" not in current_url:
                print("  ログイン成功の可能性が高いです")

                # 認証状態を保存
                context.storage_state(
                    path="/Users/masaaki_nagasawa/.claude/mercari_auth_state.json"
                )
                print("  認証状態を mercari_auth_state.json に保存しました")
            else:
                print("  ログインページに留まっています。ログインが完了していない可能性があります")
                body_text = page.locator("body").inner_text()
                print(f"  ページテキスト(先頭500文字): {body_text[:500]}")

            # ブラウザを開いたまま30秒待機
            print("ログイン処理完了。30秒後にブラウザを閉じます...")
            time.sleep(30)

        except Exception as e:
            print(f"エラーが発生しました: {e}")
            traceback.print_exc()
            page.screenshot(path=f"{screenshots_dir}/2fa_error.png")
            print(f"  エラー時スクリーンショット保存: 2fa_error.png")
            time.sleep(30)

        finally:
            context.close()
            browser.close()
            print("ブラウザを閉じました")


if __name__ == "__main__":
    main()
