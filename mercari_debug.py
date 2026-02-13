"""Debug script to inspect Mercari login element structure."""
import sys
from playwright.sync_api import sync_playwright

sys.stdout.reconfigure(line_buffering=True)

with sync_playwright() as p:
    browser = p.chromium.launch(headless=False, slow_mo=300)
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
    page.goto("https://jp.mercari.com/", wait_until="domcontentloaded", timeout=30000)
    page.wait_for_timeout(5000)

    # Inspect the header area
    print("=== Inspecting header for login elements ===")

    # Get all elements containing "ログイン" text
    result = page.evaluate("""() => {
        const elements = [];
        const walker = document.createTreeWalker(
            document.body,
            NodeFilter.SHOW_TEXT,
            null,
            false
        );
        while (walker.nextNode()) {
            if (walker.currentNode.textContent.trim() === 'ログイン') {
                const el = walker.currentNode.parentElement;
                const rect = el.getBoundingClientRect();
                elements.push({
                    tag: el.tagName,
                    text: el.textContent.trim(),
                    href: el.getAttribute('href'),
                    className: el.className,
                    id: el.id,
                    role: el.getAttribute('role'),
                    dataTestId: el.getAttribute('data-testid'),
                    outerHTML: el.outerHTML.substring(0, 500),
                    parentTag: el.parentElement ? el.parentElement.tagName : null,
                    parentClass: el.parentElement ? el.parentElement.className : null,
                    parentHref: el.parentElement ? el.parentElement.getAttribute('href') : null,
                    parentOuterHTML: el.parentElement ? el.parentElement.outerHTML.substring(0, 500) : null,
                    top: rect.top,
                    left: rect.left,
                    width: rect.width,
                    height: rect.height,
                });
            }
        }
        return elements;
    }""")

    for i, el in enumerate(result):
        print(f"\n--- Element {i} ---")
        for k, v in el.items():
            if v:
                print(f"  {k}: {v}")

    # Also check for any elements near the header that could be login
    print("\n\n=== Header navigation elements ===")
    header_html = page.evaluate("""() => {
        const nav = document.querySelector('header') || document.querySelector('nav');
        if (nav) return nav.outerHTML.substring(0, 5000);
        return 'No header/nav found';
    }""")
    print(header_html[:5000])

    browser.close()
