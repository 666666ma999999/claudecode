"""
Mercari Login Script using Playwright (sync API)
Logs into jp.mercari.com with email/password credentials.
Takes screenshots at each step for verification.

Login flow (discovered from actual page):
1. Navigate to top page (jp.mercari.com)
2. Extract the login link href from header, then navigate to it
3. On login page: enter email in "電話番号（メールアドレスも可）" field
4. Click "次へ" button
5. On next screen: enter password
6. Submit login
"""

import os
import sys
import time
from datetime import datetime
from playwright.sync_api import sync_playwright, TimeoutError as PlaywrightTimeout

# Force unbuffered output
sys.stdout.reconfigure(line_buffering=True)

# Configuration
EMAIL = "100ameros@gmail.com"
PASSWORD = "carrY-0011"
SCREENSHOT_DIR = "/Users/masaaki_nagasawa/.claude/mercari_screenshots"
BASE_URL = "https://jp.mercari.com/"

os.makedirs(SCREENSHOT_DIR, exist_ok=True)


def screenshot(page, name):
    """Take a screenshot and save it with timestamp."""
    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    path = os.path.join(SCREENSHOT_DIR, f"{ts}_{name}.png")
    page.screenshot(path=path, full_page=False)
    print(f"  [screenshot] {path}")
    return path


def main():
    with sync_playwright() as p:
        # Launch browser with visible window
        browser = p.chromium.launch(
            headless=False,
            slow_mo=500,
            args=[
                "--disable-blink-features=AutomationControlled",
            ],
        )
        context = browser.new_context(
            locale="ja-JP",
            timezone_id="Asia/Tokyo",
            viewport={"width": 1280, "height": 900},
            user_agent=(
                "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
                "AppleWebKit/537.36 (KHTML, like Gecko) "
                "Chrome/120.0.0.0 Safari/537.36"
            ),
        )
        page = context.new_page()

        # --------------------------------------------------
        # STEP 1: Navigate to Mercari top page and find login URL
        # --------------------------------------------------
        print("[STEP 1] Navigating to Mercari top page...")
        page.goto(BASE_URL, wait_until="domcontentloaded", timeout=30000)
        page.wait_for_timeout(3000)
        screenshot(page, "01_top_page")
        print(f"  URL: {page.url}")

        # Find the login link href
        print("  Searching for login link href...")
        login_href = None

        # Get all links with "ログイン" text
        login_links = page.locator('a:has-text("ログイン")')
        count = login_links.count()
        print(f"  Found {count} links with 'ログイン' text")

        for i in range(count):
            href = login_links.nth(i).get_attribute("href")
            text = login_links.nth(i).inner_text().strip()
            print(f"  Link {i}: text='{text}', href='{href}'")
            # Pick the one that is exactly "ログイン" (not "ショップ管理画面にログイン" etc.)
            if text == "ログイン" and href:
                login_href = href
                break

        if not login_href:
            # Also check for data-location or other attributes
            try:
                header_login = page.locator('header a:has-text("ログイン")').first
                login_href = header_login.get_attribute("href")
                print(f"  Header login href: {login_href}")
            except Exception:
                pass

        if not login_href:
            # Try clicking approach: click with Promise.all pattern
            print("  Could not find login href. Trying click approach...")
            try:
                login_el = page.locator('a:has-text("ログイン")').first
                login_el.click()
                page.wait_for_timeout(5000)
                print(f"  URL after click: {page.url}")
                if "login" in page.url:
                    login_href = page.url  # Already navigated
                    print(f"  Successfully navigated via click")
            except Exception as e:
                print(f"  Click approach failed: {e}")

        # --------------------------------------------------
        # STEP 2: Navigate to login page
        # --------------------------------------------------
        print(f"[STEP 2] Navigating to login page...")

        if login_href and "login" not in page.url:
            # Make absolute URL if needed
            if login_href.startswith("/"):
                login_href = "https://jp.mercari.com" + login_href
            print(f"  Login URL: {login_href}")
            page.goto(login_href, wait_until="domcontentloaded", timeout=30000)
        elif "login" in page.url:
            print(f"  Already on login page: {page.url}")
        else:
            print("  No login URL found. Trying known login URLs...")
            # Try known Mercari login URLs
            login_urls = [
                "https://login.jp.mercari.com/",
                "https://jp.mercari.com/login",
            ]
            for url in login_urls:
                try:
                    page.goto(url, wait_until="domcontentloaded", timeout=15000)
                    page.wait_for_timeout(2000)
                    body = page.inner_text("body")
                    if "ログイン" in body and "ページが見つかりません" not in body:
                        print(f"  Found working login URL: {url}")
                        break
                except Exception:
                    continue

        page.wait_for_timeout(3000)
        screenshot(page, "02_login_page")
        print(f"  URL: {page.url}")

        # --------------------------------------------------
        # STEP 3: Enter email/phone in the input field
        # --------------------------------------------------
        print("[STEP 3] Entering email address...")

        email_input = None
        email_input_selectors = [
            'input[placeholder="09000012345"]',
            'input[type="tel"]',
            'input[name="phoneOrEmail"]',
            'input[name="loginId"]',
            'input[name="phone"]',
            'input[type="email"]',
            'input[type="text"]',
        ]

        for selector in email_input_selectors:
            try:
                el = page.locator(selector).first
                if el.is_visible(timeout=3000):
                    # Make sure it's NOT the search bar
                    placeholder = el.get_attribute("placeholder") or ""
                    name_attr = el.get_attribute("name") or ""
                    print(f"  Found input: {selector} (placeholder='{placeholder}', name='{name_attr}')")
                    # Skip if it looks like a search bar
                    if "お探し" in placeholder or "search" in name_attr.lower():
                        print(f"  Skipping (looks like search bar)")
                        continue
                    email_input = el
                    break
            except Exception:
                continue

        if email_input is None:
            screenshot(page, "03_email_not_found")
            print("  ERROR: Could not find email input field.")
            print("  Page text:")
            try:
                print(page.inner_text("body")[:3000])
            except Exception:
                pass
            print("  Browser left open for 60s.")
            for _ in range(60):
                time.sleep(1)
            browser.close()
            sys.exit(1)

        email_input.click()
        page.wait_for_timeout(500)
        email_input.fill(EMAIL)
        page.wait_for_timeout(1000)
        screenshot(page, "03_email_entered")
        print(f"  Email entered: {EMAIL}")

        # --------------------------------------------------
        # STEP 4: Click "次へ" button
        # --------------------------------------------------
        print("[STEP 4] Clicking '次へ' (Next) button...")

        next_button = page.locator('button:has-text("次へ")').first
        try:
            if next_button.is_visible(timeout=3000):
                next_button.click()
                print("  Clicked '次へ' button")
            else:
                page.locator('button[type="submit"]').first.click()
                print("  Clicked submit button")
        except Exception:
            print("  Button click failed, pressing Enter...")
            page.keyboard.press("Enter")

        page.wait_for_timeout(5000)
        screenshot(page, "04_after_next")
        print(f"  URL: {page.url}")

        # --------------------------------------------------
        # STEP 5: Enter password (or handle verification code)
        # --------------------------------------------------
        print("[STEP 5] Looking for password field or verification...")

        try:
            body_text = page.inner_text("body")
        except Exception:
            body_text = ""

        # Check if this is a verification code screen
        verification_keywords = ["認証コード", "確認コード", "認証番号", "届いた", "送信しました"]
        is_verification = any(kw in body_text for kw in verification_keywords)

        if is_verification:
            screenshot(page, "05_verification_code")
            print("\n" + "=" * 60)
            print("VERIFICATION CODE REQUIRED")
            print("A verification code has been sent.")
            print("Please check your email/SMS and enter the code in the browser.")
            print("The script will wait up to 120 seconds for completion.")
            print("=" * 60)

            current_url = page.url
            try:
                for _ in range(60):
                    time.sleep(2)
                    new_url = page.url
                    if new_url != current_url and "login" not in new_url:
                        print(f"\n  Login appears successful! URL: {new_url}")
                        screenshot(page, "06_login_success_after_verify")
                        break
                else:
                    print("\n  Verification wait timed out (120s).")
                    screenshot(page, "06_verification_timeout")
            except KeyboardInterrupt:
                print("\n  User interrupted.")

            print("\n[DONE] Browser is kept open for 30 seconds.")
            for i in range(30):
                time.sleep(1)
            browser.close()
            print("Browser closed.")
            return

        # Try to find password field
        password_selectors = [
            'input[type="password"]',
            'input[name="password"]',
            'input[placeholder*="パスワード"]',
            'input[autocomplete="current-password"]',
        ]

        password_entered = False
        for selector in password_selectors:
            try:
                el = page.locator(selector).first
                if el.is_visible(timeout=5000):
                    print(f"  Found password input: {selector}")
                    el.click()
                    page.wait_for_timeout(500)
                    el.fill(PASSWORD)
                    password_entered = True
                    break
            except Exception:
                continue

        if not password_entered:
            screenshot(page, "05_password_not_found")
            print("  Password field not found.")
            print(f"  Page text:\n{body_text[:2000]}")
            print("  Browser left open for 60s.")
            for _ in range(60):
                time.sleep(1)
            browser.close()
            sys.exit(1)

        page.wait_for_timeout(1000)
        screenshot(page, "05_password_entered")

        # --------------------------------------------------
        # STEP 6: Click login/submit button
        # --------------------------------------------------
        print("[STEP 6] Clicking login button...")

        submit_selectors = [
            'button:has-text("ログインする")',
            'button:has-text("ログイン")',
            'button[type="submit"]',
            'input[type="submit"]',
        ]

        submit_clicked = False
        for selector in submit_selectors:
            try:
                el = page.locator(selector).first
                if el.is_visible(timeout=3000):
                    print(f"  Clicking submit: {selector}")
                    el.click()
                    submit_clicked = True
                    break
            except Exception:
                continue

        if not submit_clicked:
            print("  Submit button not found, pressing Enter...")
            page.keyboard.press("Enter")

        page.wait_for_timeout(5000)
        screenshot(page, "06_after_login_click")
        print(f"  URL: {page.url}")

        # --------------------------------------------------
        # STEP 7: Check for 2FA or successful login
        # --------------------------------------------------
        print("[STEP 7] Checking login result...")

        current_url = page.url
        try:
            page_text = page.inner_text("body")
        except Exception:
            page_text = ""

        twofa_keywords = [
            "認証コード", "確認コード", "SMS", "二段階認証",
            "本人確認", "verification", "verify",
            "電話番号に届いた", "セキュリティコード", "認証番号",
        ]
        is_2fa = any(kw in page_text for kw in twofa_keywords)

        if is_2fa:
            screenshot(page, "07_2fa_required")
            print("\n" + "=" * 60)
            print("2-STEP VERIFICATION REQUIRED")
            print("Please complete the verification in the browser window.")
            print("The script will wait up to 120 seconds.")
            print("=" * 60)

            try:
                for _ in range(60):
                    time.sleep(2)
                    new_url = page.url
                    if new_url != current_url and "signin" not in new_url and "login" not in new_url:
                        print(f"\n  Login appears successful! URL: {new_url}")
                        screenshot(page, "08_login_success")
                        break
                else:
                    print("\n  2FA wait timed out (120s).")
                    screenshot(page, "08_2fa_timeout")
            except KeyboardInterrupt:
                print("\n  User interrupted.")

        error_keywords = ["エラー", "失敗", "正しくありません", "invalid", "incorrect"]
        has_error = any(kw.lower() in page_text.lower() for kw in error_keywords)

        if has_error:
            screenshot(page, "07_login_error")
            print("  Login may have failed. Check the screenshot.")

        if not is_2fa and not has_error:
            if "signin" not in current_url and "login" not in current_url:
                print("  Login appears successful!")
                screenshot(page, "07_login_success")
            else:
                print("  Still on login-related page.")
                screenshot(page, "07_still_on_login")

        # --------------------------------------------------
        # Keep browser open for inspection
        # --------------------------------------------------
        print("\n[DONE] Browser is kept open for 30 seconds.")
        try:
            for i in range(30):
                time.sleep(1)
        except KeyboardInterrupt:
            print("\nClosing browser early...")

        browser.close()
        print("Browser closed. Script finished.")


if __name__ == "__main__":
    main()
