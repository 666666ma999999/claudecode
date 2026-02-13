"""
Mercari Login Script using Playwright (sync API)
Logs into jp.mercari.com with email/password credentials.
Takes screenshots at each step for verification.

Login flow:
1. Navigate to top page
2. Click login link -> navigates to login.jp.mercari.com
3. Enter email in "phone/email" field
4. Click "next" button
5. Enter password on next screen
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
        # STEP 1: Navigate directly to login page
        # --------------------------------------------------
        print("[STEP 1] Navigating directly to Mercari login page...")
        page.goto("https://jp.mercari.com/signin", wait_until="domcontentloaded", timeout=30000)
        page.wait_for_timeout(3000)
        screenshot(page, "01_login_page")
        print(f"  URL: {page.url}")

        # --------------------------------------------------
        # STEP 2: Enter email/phone in the input field
        # The login page has a single field: "phone number (email also OK)"
        # with placeholder "09000012345"
        # --------------------------------------------------
        print("[STEP 2] Entering email address...")

        # The login page field label: "電話番号（メールアドレスも可）"
        # Try multiple selectors for the phone/email input
        email_input_selectors = [
            'input[placeholder="09000012345"]',
            'input[name="phoneOrEmail"]',
            'input[name="loginId"]',
            'input[name="phone"]',
            'input[type="tel"]',
            'input[type="email"]',
            'input[type="text"]',
        ]

        email_entered = False
        for selector in email_input_selectors:
            try:
                el = page.locator(selector).first
                if el.is_visible(timeout=3000):
                    print(f"  Found input: {selector}")
                    el.click()
                    page.wait_for_timeout(500)
                    el.fill(EMAIL)
                    email_entered = True
                    break
            except Exception as e:
                print(f"  Selector {selector} failed: {e}")
                continue

        if not email_entered:
            screenshot(page, "02_email_not_found")
            print("  ERROR: Could not find email input field.")
            # Dump page structure for debugging
            print("  Page text:")
            try:
                print(page.inner_text("body")[:2000])
            except Exception:
                pass
            browser.close()
            sys.exit(1)

        page.wait_for_timeout(1000)
        screenshot(page, "02_email_entered")

        # --------------------------------------------------
        # STEP 3: Click "next" button
        # --------------------------------------------------
        print("[STEP 3] Clicking 'next' button...")

        next_selectors = [
            'button:has-text("次へ")',
            'button[type="submit"]',
            'input[type="submit"]',
        ]

        next_clicked = False
        for selector in next_selectors:
            try:
                el = page.locator(selector).first
                if el.is_visible(timeout=3000):
                    print(f"  Found next button: {selector}")
                    el.click()
                    next_clicked = True
                    break
            except Exception:
                continue

        if not next_clicked:
            print("  Next button not found, pressing Enter...")
            page.keyboard.press("Enter")

        # Wait for next page to load
        page.wait_for_timeout(5000)
        screenshot(page, "03_after_next")
        print(f"  URL: {page.url}")

        # --------------------------------------------------
        # STEP 4: Enter password
        # The next screen should show a password field
        # --------------------------------------------------
        print("[STEP 4] Looking for password field...")

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
            screenshot(page, "04_password_not_found")
            print("  Password field not found.")
            print("  Checking page content for clues...")
            try:
                body_text = page.inner_text("body")
                print(f"  Page text (first 2000 chars):\n{body_text[:2000]}")
            except Exception:
                pass

            # Maybe it's a verification code screen or different flow
            # Check if there's a "verification code" or SMS screen
            try:
                body_text = page.inner_text("body")
                if "認証" in body_text or "コード" in body_text or "SMS" in body_text:
                    print("\n  ** This appears to be a verification/SMS code screen. **")
                    print("  Mercari may use passwordless login (SMS/email verification code).")
                    print("  Browser left open for 60s for manual completion.")
                    for _ in range(60):
                        time.sleep(1)
                    screenshot(page, "04_final_state")
                    browser.close()
                    sys.exit(0)
            except Exception:
                pass

            print("  Browser left open for 60s for inspection.")
            for _ in range(60):
                time.sleep(1)
            browser.close()
            sys.exit(1)

        page.wait_for_timeout(1000)
        screenshot(page, "04_password_entered")

        # --------------------------------------------------
        # STEP 5: Click login/submit button
        # --------------------------------------------------
        print("[STEP 5] Clicking login button...")

        submit_selectors = [
            'button:has-text("ログインする")',
            'button:has-text("ログイン")',
            'button[type="submit"]',
            'input[type="submit"]',
            'button:has-text("サインイン")',
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

        # Wait for navigation / response
        page.wait_for_timeout(5000)
        screenshot(page, "05_after_login_click")
        print(f"  URL: {page.url}")

        # --------------------------------------------------
        # STEP 6: Check for 2FA or successful login
        # --------------------------------------------------
        print("[STEP 6] Checking login result...")

        current_url = page.url
        try:
            page_text = page.inner_text("body")
        except Exception:
            page_text = ""

        # Check for 2FA / verification
        twofa_keywords = [
            "認証コード",
            "確認コード",
            "SMS",
            "二段階認証",
            "本人確認",
            "verification",
            "verify",
            "電話番号に届いた",
            "セキュリティコード",
            "認証番号",
        ]

        is_2fa = False
        for keyword in twofa_keywords:
            if keyword in page_text:
                is_2fa = True
                print(f"  ** 2FA/Verification detected: '{keyword}' found on page **")
                break

        if is_2fa:
            screenshot(page, "06_2fa_required")
            print("\n" + "=" * 60)
            print("2-STEP VERIFICATION REQUIRED")
            print("Please complete the verification in the browser window.")
            print("The script will wait up to 120 seconds.")
            print("=" * 60)

            # Wait for user to complete 2FA (up to 120 seconds)
            try:
                for _ in range(60):
                    time.sleep(2)
                    new_url = page.url
                    if new_url != current_url and "signin" not in new_url and "login" not in new_url:
                        print(f"\n  Login appears successful! URL: {new_url}")
                        screenshot(page, "07_login_success")
                        break
                else:
                    print("\n  2FA wait timed out (120s). Taking final screenshot.")
                    screenshot(page, "07_2fa_timeout")
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
            screenshot(page, "06_login_error")
            print("  Login may have failed. Check the screenshot.")

        # Check if we are on the main page (login successful)
        if not is_2fa and not has_error:
            if "signin" not in current_url and "login" not in current_url:
                print("  Login appears successful!")
                screenshot(page, "06_login_success")
            else:
                print("  Still on login-related page. May need manual verification.")
                screenshot(page, "06_still_on_login")

        # --------------------------------------------------
        # Keep browser open for inspection (30 seconds)
        # --------------------------------------------------
        print("\n[DONE] Browser is kept open for 30 seconds for inspection.")
        try:
            for i in range(30):
                time.sleep(1)
        except KeyboardInterrupt:
            print("\nClosing browser early...")

        browser.close()
        print("Browser closed. Script finished.")


if __name__ == "__main__":
    main()
