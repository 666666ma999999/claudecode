# トラブルシューティング詳細

## よくある落とし穴と対策

### 1. 新しいページ作成直後のナビゲーションエラー

**症状:**
```
Page.goto: Navigation to "https://..." is interrupted by another navigation to "about:blank"
```

**原因:** `new_page()` 直後は `about:blank` への初期ナビゲーションが進行中

**対策:**
```python
self.page = await self.context.new_page()
# ページが準備されるまで待機（必須）
await self.page.wait_for_load_state("domcontentloaded")
# この後でgoto()を実行
await self.page.goto("https://example.com")
```

### 2. ダイアログハンドラーが動作しない

**症状:** `page.on("dialog", lambda dialog: dialog.accept())` で403エラーや予期しない動作

**原因:** `dialog.accept()` は非同期メソッドだが、lambdaでawaitできない

**対策:**
```python
import asyncio

def handle_dialog(dialog):
    logger.info(f"ダイアログ検出: {dialog.message}")
    asyncio.ensure_future(dialog.accept())  # 正しい非同期処理

page.on("dialog", handle_dialog)
```

### 3. コンテキスト切り替え時の認証エラー

**症状:** 複数サイトで異なるBasic認証を使う際、2つ目のサイトで認証失敗

**対策:**
```python
# 古いコンテキストを確実に閉じてから新しいコンテキストを作成
if self.context:
    await self.context.close()

self.context = await self.browser.new_context(
    http_credentials={"username": "user", "password": "pass"}
)
```

### 4. DOM要素のインデックスずれ（コンテンツベースマッチング）

**症状:** データが正しく存在するのにALL項目でマッチ失敗（0/N件）

**原因:** `page_elements[i]` と `registered_data[i]` のインデックスが対応しない。ページに余分な構造要素（見出し、ナビゲーション等）が含まれる場合、全てのインデックスがずれる。

**検出:** `len(page_elements) != len(registered_data)` の場合は要注意

**対策:**
```python
# BAD: 固定インデックスマッピング（余分な要素でずれる）
for i, data_item in enumerate(registered_data):
    page_text = await page_elements[i].inner_text()
    if matches(data_item, page_text): ...

# GOOD: コンテンツベースマッチング
used = set()
for data_item in registered_data:
    best_match = find_best_matching_element(data_item, page_elements, exclude=used)
    if best_match:
        used.add(best_match.index)
```

## 接続エラーのパターン判定

ナビゲーション時のエラーを適切にハンドリング：

```python
async def navigate_with_error_handling(page, url: str) -> tuple[bool, str]:
    """エラーパターンを判定してわかりやすいメッセージを返す"""
    try:
        response = await page.goto(url, wait_until="domcontentloaded", timeout=30000)

        # HTTPエラーチェック
        if response and response.status >= 400:
            return False, f"HTTPエラー: {response.status}"

        # リダイレクトループ/接続エラー検出
        current_url = page.url
        if "chrome-error" in current_url or "about:blank" in current_url:
            return False, "接続エラー（VPN接続またはBasic認証を確認）"

        return True, ""

    except Exception as e:
        error_str = str(e)
        error_patterns = {
            "ERR_TOO_MANY_REDIRECTS": "リダイレクトループ（VPN接続が必要な可能性）",
            "ERR_INVALID_AUTH_CREDENTIALS": "Basic認証エラー（認証情報を確認）",
            "ERR_CONNECTION_REFUSED": "接続拒否（サーバーに接続できません）",
            "ERR_NAME_NOT_RESOLVED": "DNS解決エラー（URLを確認）",
            "Timeout": "タイムアウト（ネットワーク接続を確認）",
        }
        for pattern, message in error_patterns.items():
            if pattern in error_str:
                return False, message
        return False, f"接続エラー: {error_str}"
```

## Docker + VNC でのGUI実行は不安定（ローカル推奨）

### 背景

Dockerコンテナ内でPlaywrightをGUIモード（`headless=False`）で実行したい場合、VNC環境を構築する方法がある。

### 構成例

```dockerfile
FROM mcr.microsoft.com/playwright/python:v1.57.0-jammy
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    xvfb x11vnc fluxbox novnc websockify supervisor

# supervisordで Xvfb + fluxbox + x11vnc + novnc を起動
```

### 実際に遭遇した問題

| 問題 | 詳細 |
|------|------|
| VNC接続後に画面が表示されない | noVNCでConnectしても黒画面/空白 |
| novncパス変更 | Ubuntu版ではパスが異なり起動スクリプト修正が必要 |
| tzdata対話プロンプト | `DEBIAN_FRONTEND=noninteractive` 必須 |
| X11転送の複雑さ | macOSではXQuartz + socat設定が必要で不安定 |

### 結論：ローカル実行を推奨

**Docker + VNC は設定が複雑で不安定**。以下の理由からローカル実行を推奨：

```
Docker + VNC:
  設定が複雑（Xvfb, VNC, noVNC, supervisor）
  接続問題が頻発
  デバッグが困難
  パフォーマンス低下

ローカル実行:
  セットアップが簡単（venv + playwright install）
  画面が直接見える
  デバッグしやすい
  CDP接続でCookie取得可能
```

### ローカル環境セットアップ

```bash
# 仮想環境作成
python3 -m venv venv
source venv/bin/activate

# インストール
pip install playwright
playwright install chromium

# 実行
python your_script.py
```

### Dockerが必要な場合

本番環境やCI/CDでDockerが必須の場合は、**headless=True**で実行：

```python
browser = playwright.chromium.launch(headless=True)
```

ただしheadlessモードはbot検知されやすいため、事前にローカルでCookieを取得しておく。

## エラーハンドリング

```python
from playwright.async_api import TimeoutError as PlaywrightTimeout

try:
    await page.goto(url, timeout=30000)
    await page.locator(".element").click(timeout=5000)
except PlaywrightTimeout:
    # タイムアウトエラー
    await page.screenshot(path="error_timeout.png")
    raise
except Exception as e:
    # その他のエラー
    await page.screenshot(path="error_general.png")
    raise
```

## 実装前の必須確認事項

**ワークフロー自動化では、実装前に以下を必ずユーザーに確認：**

1. **完全なワークフロー**
   - 画面遷移の順序（URL）
   - 各画面でクリックする要素
   - 出現するダイアログとそのメッセージ
   - 期待される最終画面

2. **各ステップの詳細**
   - ボタンのテキストまたはセレクタ
   - ラジオボタン/チェックボックスの選択肢
   - 入力フィールドの値

3. **エラー時の挙動**
   - 何が表示されたら失敗か
   - リトライは必要か

**教訓:** ワークフローの一部でも不明な場合、実装を開始しない。
確認不足で実装すると、デバッグに何倍もの時間がかかる。
