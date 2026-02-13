"""
Mercari Login Script using Playwright (sync API)
Logs into jp.mercari.com with email/password credentials.
Takes screenshots at each step for verification.
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
        # STEP 1: Navigate to Mercari top page
        # --------------------------------------------------
        print("[STEP 1] Navigating to Mercari top page...")
        page.goto(BASE_URL, wait_until="domcontentloaded", timeout=30000)
        page.wait_for_timeout(2000)
        screenshot(page, "01_top_page")
        print(f"  URL: {page.url}")

        # --------------------------------------------------
        # STEP 2: Find and click the login button/link
        # --------------------------------------------------
        print("[STEP 2] Looking for login button...")

        login_clicked = False
        # Try various selectors for the login link/button
        login_selectors = [
            'a:has-text("ログイン")',
            'button:has-text("ログイン")',
            '[data-testid="login-button"]',
            '[href*="login"]',
            '[href*="signin"]',
            'text=ログイン',
            'a:has-text("マイページ")',
        ]

        for selector in login_selectors:
            try:
                el = page.locator(selector).first
                if el.is_visible(timeout=2000):
                    print(f"  Found login element: {selector}")
                    el.click()
                    login_clicked = True
                    break
            except Exception:
                continue

        if not login_clicked:
            # Fallback: navigate directly to login URL
            print("  Login button not found, trying direct navigation...")
            page.goto("https://jp.mercari.com/signin", wait_until="domcontentloaded", timeout=30000)

        page.wait_for_timeout(3000)
        screenshot(page, "02_login_page")
        print(f"  URL: {page.url}")

        # --------------------------------------------------
        # STEP 3: Select email login option
        # --------------------------------------------------
        print("[STEP 3] Looking for email login option...")

        email_option_selectors = [
            'button:has-text("メールアドレスでログイン")',
            'a:has-text("メールアドレスでログイン")',
            'button:has-text("メールアドレス")',
            'a:has-text("メールアドレス")',
            'text=メールアドレスでログイン',
            '[data-testid="email-login"]',
            'button:has-text("メール")',
        ]

        email_option_clicked = False
        for selector in email_option_selectors:
            try:
                el = page.locator(selector).first
                if el.is_visible(timeout=2000):
                    print(f"  Found email option: {selector}")
                    el.click()
                    email_option_clicked = True
                    break
            except Exception:
                continue

        if not email_option_clicked:
            print("  Email login option not found as a separate button.")
            print("  Checking if email input is already visible...")

        page.wait_for_timeout(2000)
        screenshot(page, "03_email_option")
        print(f"  URL: {page.url}")

        # --------------------------------------------------
        # STEP 4: Enter email address
        # --------------------------------------------------
        print("[STEP 4] Entering email address...")

        email_selectors = [
            'input[type="email"]',
            'input[name="email"]',
            'input[placeholder*="メール"]',
            'input[placeholder*="email"]',
            'input[autocomplete="email"]',
            'input[name="loginId"]',
            'input[type="text"]',
        ]

        email_entered = False
        for selector in email_selectors:
            try:
                el = page.locator(selector).first
                if el.is_visible(timeout=2000):
                    print(f"  Found email input: {selector}")
                    el.click()
                    el.fill(EMAIL)
                    email_entered = True
                    break
            except Exception:
                continue

        if not email_entered:
            screenshot(page, "04_email_not_found")
            print("  ERROR: Could not find email input field.")
            print("  Page content sample:")
            print(page.content()[:3000])
            browser.close()
            sys.exit(1)

        page.wait_for_timeout(1000)
        screenshot(page, "04_email_entered")

        # --------------------------------------------------
        # STEP 5: Enter password
        # --------------------------------------------------
        print("[STEP 5] Entering password...")

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
                if el.is_visible(timeout=2000):
                    print(f"  Found password input: {selector}")
                    el.click()
                    el.fill(PASSWORD)
                    password_entered = True
                    break
            except Exception:
                continue

        if not password_entered:
            # Password field might appear after submitting email
            print("  Password field not visible yet. Trying to submit email first...")

            # Look for a "next" or "continue" button
            next_selectors = [
                'button:has-text("次へ")',
                'button:has-text("ログイン")',
                'button[type="submit"]',
                'input[type="submit"]',
                'button:has-text("Continue")',
                'button:has-text("Next")',
            ]
            for selector in next_selectors:
                try:
                    el = page.locator(selector).first
                    if el.is_visible(timeout=2000):
                        print(f"  Clicking next/submit: {selector}")
                        el.click()
                        break
                except Exception:
                    continue

            page.wait_for_timeout(3000)
            screenshot(page, "05_after_email_submit")

            # Try password fields again
            for selector in password_selectors:
                try:
                    el = page.locator(selector).first
                    if el.is_visible(timeout=3000):
                        print(f"  Found password input (2nd attempt): {selector}")
                        el.click()
                        el.fill(PASSWORD)
                        password_entered = True
                        break
                except Exception:
                    continue

        if not password_entered:
            screenshot(page, "05_password_not_found")
            print("  ERROR: Could not find password input field.")
            print("  Page content sample:")
            print(page.content()[:3000])
            # Keep browser open for manual inspection (30s)
            print("  Browser left open for 30s for inspection.")
            time.sleep(30)
            browser.close()
            sys.exit(1)

        page.wait_for_timeout(1000)
        screenshot(page, "05_password_entered")

        # --------------------------------------------------
        # STEP 6: Click the login/submit button
        # --------------------------------------------------
        print("[STEP 6] Clicking login button...")

        submit_selectors = [
            'button:has-text("ログイン")',
            'button[type="submit"]',
            'input[type="submit"]',
            'button:has-text("ログインする")',
            'button:has-text("サインイン")',
        ]

        submit_clicked = False
        for selector in submit_selectors:
            try:
                el = page.locator(selector).first
                if el.is_visible(timeout=2000):
                    print(f"  Clicking submit: {selector}")
                    el.click()
                    submit_clicked = True
                    break
            except Exception:
                continue

        if not submit_clicked:
            # Try pressing Enter as fallback
            print("  Submit button not found, pressing Enter...")
            page.keyboard.press("Enter")

        # Wait for navigation / response
        page.wait_for_timeout(5000)
        screenshot(page, "06_after_login_click")
        print(f"  URL: {page.url}")

        # --------------------------------------------------
        # STEP 7: Check for 2FA or successful login
        # --------------------------------------------------
        print("[STEP 7] Checking login result...")

        current_url = page.url
        page_text = page.inner_text("body")

        # Check for 2FA / verification
        twofa_keywords = [
            "認証コード",
            "確認コード",
            "SMS",
            "二段階認証",
            "本人確認",
            "verification",
            "verify",
            "電話番号",
            "セキュリティコード",
        ]

        is_2fa = False
        for keyword in twofa_keywords:
            if keyword in page_text:
                is_2fa = True
                print(f"  ** 2FA/Verification detected: '{keyword}' found on page **")
                break

        if is_2fa:
            screenshot(page, "07_2fa_required")
            print("\n" + "=" * 60)
            print("2-STEP VERIFICATION REQUIRED")
            print("Please complete the verification in the browser window.")
            print("The script will wait. Press Ctrl+C to exit when done.")
            print("=" * 60)

            # Wait for user to complete 2FA (up to 120 seconds)
            try:
                for _ in range(60):
                    time.sleep(2)
                    new_url = page.url
                    if new_url != current_url and "signin" not in new_url and "login" not in new_url:
                        print(f"\n  Login appears successful! URL: {new_url}")
                        screenshot(page, "08_login_success")
                        break
                else:
                    print("\n  2FA wait timed out (120s). Taking final screenshot.")
                    screenshot(page, "08_2fa_timeout")
            except KeyboardInterrupt:
                print("\n  User interrupted.")

        # Check for error messages
        error_keywords = ["エラー", "失敗", "正しくありません", "invalid", "error", "incorrect"]
        has_error = False
        for keyword in error_keywords:
            if keyword.lower() in page_text.lower():
                has_error = True
                print(f"  ** Possible error detected: '{keyword}' **")
                break

        if has_error:
            screenshot(page, "07_login_error")
            print("  Login may have failed. Check the screenshot.")

        # Check if we are on the main page (login successful)
        if not is_2fa and not has_error:
            if "signin" not in current_url and "login" not in current_url:
                print("  Login appears successful!")
                screenshot(page, "07_login_success")
            else:
                print("  Still on login-related page. May need manual verification.")
                screenshot(page, "07_still_on_login")

        # --------------------------------------------------
        # Keep browser open for inspection (30 seconds)
        # --------------------------------------------------
        print("\n[DONE] Browser is kept open for 30 seconds for inspection.")
        print("Press Ctrl+C to close earlier.")
        try:
            for i in range(30):
                time.sleep(1)
        except KeyboardInterrupt:
            print("\nClosing browser early...")

        browser.close()
        print("Browser closed. Script finished.")


if __name__ == "__main__":
    main()
