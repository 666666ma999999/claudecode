# Bot検知回避パターン詳細

## MCP使用時のGoogleログインブロック問題

### 症状

MCP（Chrome DevTools MCP / Playwright MCP）使用中に、Chromeで以下のエラーが表示される：

```
ログインできませんでした
このブラウザまたはアプリは安全でない可能性があります。
別のブラウザをお試しください。
```

### 原因

MCPはChromeを**自動化フラグ付き**で起動する：

```bash
--enable-automation              # 自動化モードフラグ
--remote-debugging-port=XXXXX    # リモートデバッグ有効
--user-data-dir=/特殊な場所/       # 通常とは別のプロファイル
```

Googleはこれらのフラグを検出し、ボット/スクレイピングと判断してログインをブロックする。

### 解決策

#### 1. headlessモードを使用（推奨）

`.mcp.json`でheadlessモードを指定：

```json
{
  "mcpServers": {
    "playwright": {
      "command": "npx",
      "args": ["@anthropic/mcp-playwright", "--headless"]
    }
  }
}
```

**メリット:** ブラウザ画面が表示されないので、通常のChromeと混同しない

#### 2. 通常のChromeと自動化用Chromeを使い分ける

| 用途 | 使用するChrome |
|------|---------------|
| Googleログイン、普段使い | Dockから起動した**通常のChrome** |
| スクレイピング、自動化 | **MCP経由で起動される自動化用Chrome** |

#### 3. 自動化用Chromeの見分け方

| 項目 | 通常のChrome | 自動化用Chrome |
|------|-------------|---------------|
| 起動方法 | Dockクリック | MCP経由で自動起動 |
| 警告バー | なし | 「Chromeは自動テストソフトウェアによって制御されています」 |
| ブックマーク | あなたのもの | 空 or 別物 |

### 復旧手順

自動化用ChromeでGoogleログインしようとしてブロックされた場合：

```bash
# 1. すべてのChromeプロセスを終了
pkill -f "Google Chrome"

# 2. Dockから通常のChromeを起動
# → これでGoogleにログイン可能
```

### 教訓

- **自動化用ブラウザではGoogleログインは不可**
- headlessモードを使えば混同を防げる
- 認証が必要なサイトの自動化は `storage_state` で認証状態を保存・復元する方法を使う

---

## MCP使用時のユーザーChromeブラウザ保護（必須）

### 絶対禁止事項

MCP（Playwright MCP / Chrome DevTools MCP）使用時、以下の操作は**絶対に行わない**：

| 禁止操作 | 理由 |
|---------|------|
| ユーザーのChromeプロファイルへのアクセス | 拡張機能・ブックマーク・認証情報が消失する |
| `--user-data-dir` でユーザープロファイル指定 | プロファイル破損の原因 |
| Googleアカウントへのログイン操作 | ボット検知でアカウントがブロックされる可能性 |
| ユーザーの通常Chrome使用中のMCP操作 | セッション競合でデータ破損 |

### MCPツール使用時の必須ルール

```
1. headlessモードを優先使用
2. ユーザーのChromeプロファイルには絶対にアクセスしない
3. 認証が必要な場合はCookie/storage_stateを使用（プロファイル直接使用禁止）
4. MCP操作前にユーザーの通常Chromeに影響がないことを確認
```

### 安全な使用パターン

```python
# 安全: 独立したブラウザインスタンス
browser = await playwright.chromium.launch(headless=True)
context = await browser.new_context()

# 安全: 認証状態を別途保存・読み込み
context = await browser.new_context(storage_state="auth_state.json")

# 危険: ユーザープロファイル直接使用
context = await playwright.chromium.launch_persistent_context(
    "~/Library/Application Support/Google/Chrome",  # 絶対禁止
    ...
)
```

### MCP操作後の確認事項

MCPでブラウザ操作を行った後：
1. ユーザーの通常Chromeが正常に起動するか確認
2. 拡張機能が残っているか確認
3. Googleアカウントにログインできるか確認

### 問題が発生した場合の復旧

```bash
# 1. すべてのChromeを終了
pkill -9 "Google Chrome"

# 2. chrome://settings/syncSetup にアクセス
# 3. 「拡張機能」の同期がONか確認
# 4. Googleアカウントで再ログインして同期復元
```

---

## ユーザープロファイル使用の危険性と対策

### 絶対に避けるべき設定

```python
# 危険: ユーザーの実際のChromeプロファイルを使用
@dataclass
class Config:
    use_user_profile: bool = True  # 絶対にデフォルトTrueにしない

# 危険: 直接ユーザープロファイルを指定
context = await playwright.chromium.launch_persistent_context(
    "~/Library/Application Support/Google/Chrome",  # ユーザーの実プロファイル
    ...
)
```

### 何が起きるか

1. **ブックマーク消失/破損**: Bookmarksファイルが上書き・破損
2. **ファビコン消失**: Faviconsデータベースが破損し、全アイコンが同一に
3. **認証情報消失**: Cookieやログイン状態が失われる
4. **拡張機能の設定消失**: Chromeの拡張機能設定がリセット

### 安全な設定（必須）

```python
@dataclass
class Config:
    use_user_profile: bool = False  # 必ずFalseをデフォルトに
    chrome_user_data_dir: Optional[str] = None

# 安全: 独立したセッションを使用
browser = await playwright.chromium.launch(headless=False)
context = await browser.new_context()
```

### 認証が必要な場合の安全な方法

```python
# 安全: プロファイルをコピーして使用（前述のcopy_chrome_profile()を使用）
temp_profile = copy_chrome_profile()
try:
    context = await playwright.chromium.launch_persistent_context(
        temp_profile,
        headless=False,
    )
    # ... 処理 ...
finally:
    shutil.rmtree(temp_profile)  # 必ずクリーンアップ
```

### Chromeプロファイル復旧手順

もしプロファイルが破損した場合：

```bash
# 1. Chromeを完全に終了
pkill -9 "Google Chrome"

# 2. バックアップの確認
ls -la ~/Library/Application\ Support/Google/Chrome/*/Bookmarks*

# 3. 使用中のプロファイル確認（Local Stateから）
cat "~/Library/Application Support/Google/Chrome/Local State" | python3 -c "
import json, sys
data = json.load(sys.stdin)
print('最後に使用:', data.get('profile', {}).get('last_used'))
"

# 4. ブックマーク復元（例: Defaultプロファイルの場合）
cp "~/Library/Application Support/Google/Chrome/Profile 1/Bookmarks.bak" \
   "~/Library/Application Support/Google/Chrome/Default/Bookmarks"

# 5. ファビコン復元（アイコンが消えた場合）
cp "~/Library/Application Support/Google/Chrome/Profile 1/Favicons" \
   "~/Library/Application Support/Google/Chrome/Default/Favicons"

# 6. Chrome起動
open -a "Google Chrome"
```

### チェックリスト（実装時に必ず確認）

- [ ] `use_user_profile`のデフォルト値は`False`か
- [ ] ユーザープロファイルを直接参照していないか
- [ ] プロファイルをコピーする場合、終了時にクリーンアップしているか
- [ ] 設定クラスが複数ある場合、全てチェックしたか

## Chromeプロファイルの使用（認証済みセッション再利用）

既存のChrome認証情報（Cookie、ログイン状態）を再利用したい場合：

### プロファイルコピー戦略（推奨）

既存のChromeが起動中でもプロファイルを使用できるよう、コピーして使用する：

```python
import shutil
import tempfile
from pathlib import Path

def copy_chrome_profile() -> str:
    """Chromeプロファイルを一時ディレクトリにコピー"""
    # macOSのデフォルトパス
    source_dir = Path.home() / "Library/Application Support/Google/Chrome"
    temp_dir = Path(tempfile.mkdtemp(prefix="chrome_profile_"))

    # 認証情報関連のファイルのみコピー
    items_to_copy = [
        "Default/Cookies",
        "Default/Login Data",
        "Default/Web Data",
        "Default/Preferences",
        "Local State",
    ]

    (temp_dir / "Default").mkdir(parents=True, exist_ok=True)
    for item in items_to_copy:
        src = source_dir / item
        dst = temp_dir / item
        if src.exists():
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, dst)

    return str(temp_dir)

# 使用例
temp_profile = copy_chrome_profile()
context = await playwright.chromium.launch_persistent_context(
    temp_profile,
    headless=False,
    channel="chrome",  # システムのChromeを使用
)

# 終了時にクリーンアップ
shutil.rmtree(temp_profile)
```

### 注意点
- 既存Chromeと同時使用可能（コピーなので競合しない）
- 終了時に一時ディレクトリを必ず削除
- `channel="chrome"` でシステムのChromeバイナリを使用
- **`launch_persistent_context`使用時、`self.browser`はNone**。別サイト用に新コンテキストが必要な場合は`self._playwright.chromium.launch()`で独立ブラウザを起動すること

## 環境変数ベースの認証管理パターン

ログイン自動化スクリプトで認証情報をハードコードしない方法。

### 問題

スクリプトにメールアドレス・パスワードを直接記述すると:
- git commitで認証情報が漏洩するリスク
- スクリプト共有時にパスワード流出
- 複数環境での使い回しが困難

### 解決策: 環境変数 + .envファイル

```python
import os

def get_credentials(service_name: str) -> tuple[str, str]:
    """環境変数から認証情報を取得"""
    prefix = service_name.upper()  # e.g., "SERVICE_NAME"
    email = os.environ.get(f"{prefix}_EMAIL")
    password = os.environ.get(f"{prefix}_PASSWORD")

    if not email or not password:
        raise ValueError(
            f"{prefix}_EMAIL と {prefix}_PASSWORD を環境変数に設定してください。\n"
            f"例: export {prefix}_EMAIL='user@example.com'"
        )
    return email, password

# 使用例
email, password = get_credentials("SERVICE_NAME")
```

### .envファイル（gitignore対象）

```bash
# .env
SERVICE_NAME_EMAIL=user@example.com
SERVICE_NAME_PASSWORD=your_password
```

### .envの読み込み（python-dotenvなし）

```python
from pathlib import Path

def load_env(env_path: str = ".env"):
    """簡易.envローダー（外部ライブラリ不要）"""
    env_file = Path(env_path)
    if not env_file.exists():
        return
    for line in env_file.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        key, _, value = line.partition("=")
        os.environ.setdefault(key.strip(), value.strip().strip("'\""))

# スクリプト冒頭で呼び出し
load_env()
email, password = get_credentials("SERVICE_NAME")
```

### .gitignoreへの追記（必須）

```
.env
*.env
.env.*
```
