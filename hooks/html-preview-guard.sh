#!/bin/bash
# PreToolUse:Bash hook — `open *.html` の前にPlaywrightで表示検証
# JSエラーなし・bodyが空でない・EChartsが描画されている を確認

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_name',''))" 2>/dev/null)
COMMAND=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('command',''))" 2>/dev/null)

# open *.html のパターン以外はスキップ
case "$COMMAND" in
    open*\.html*) ;;
    *) exit 0 ;;
esac

# HTMLファイルパスを抽出
HTML_PATH=$(echo "$COMMAND" | grep -oE '[^ ]+\.html' | head -1)
[ -z "$HTML_PATH" ] && exit 0
[ ! -f "$HTML_PATH" ] && exit 0

# Playwrightで検証
RESULT=$(python3 -I << PYEOF 2>&1
import sys
try:
    from playwright.sync_api import sync_playwright
except ImportError:
    print("SKIP:playwright-not-installed")
    sys.exit(0)

html_path = "$HTML_PATH"
errors = []
warnings = []

with sync_playwright() as p:
    browser = p.chromium.launch()
    page = browser.new_page(viewport={"width": 1400, "height": 900})

    js_errors = []
    page.on("pageerror", lambda err: js_errors.append(str(err)))

    page.goto(f"file://{html_path}")
    page.wait_for_timeout(3000)

    # 1. JSエラーチェック
    if js_errors:
        errors.append(f"JS errors: {len(js_errors)}")
        for e in js_errors[:3]:
            errors.append(f"  {e[:200]}")

    # 2. body空チェック
    body_text = page.inner_text("body").strip()
    if len(body_text) < 10:
        errors.append(f"Body is empty or near-empty ({len(body_text)} chars)")

    # 3. EChartsチェック（存在する場合のみ）
    has_echarts = page.evaluate("typeof echarts !== 'undefined'")
    if has_echarts:
        echarts_count = page.evaluate("""() => {
            const canvases = document.querySelectorAll('canvas');
            let rendered = 0;
            canvases.forEach(c => { if (c.width > 0 && c.height > 0) rendered++; });
            return { total: canvases.length, rendered };
        }""")
        if echarts_count['total'] > 0 and echarts_count['rendered'] == 0:
            errors.append(f"ECharts canvases exist ({echarts_count['total']}) but none rendered")
        elif echarts_count['total'] == 0:
            warnings.append("ECharts loaded but no canvas elements found")

    browser.close()

if errors:
    print("FAIL:" + "|".join(errors))
else:
    print("PASS:" + ("|".join(warnings) if warnings else "OK"))
PYEOF
)

# 結果判定
case "$RESULT" in
    SKIP:*)
        exit 0
        ;;
    FAIL:*)
        DETAIL=$(echo "$RESULT" | sed 's/^FAIL://')
        echo "{\"decision\":\"block\",\"reason\":\"🛑 HTML表示検証失敗: $DETAIL\"}"
        exit 0
        ;;
    PASS:*)
        DETAIL=$(echo "$RESULT" | sed 's/^PASS://')
        if [ "$DETAIL" != "OK" ]; then
            echo "{\"systemMessage\":\"⚠️ HTML表示検証警告: $DETAIL\"}"
        fi
        exit 0
        ;;
    *)
        # Playwright実行自体のエラー
        echo "{\"systemMessage\":\"⚠️ HTML検証スクリプトエラー: $RESULT\"}"
        exit 0
        ;;
esac
