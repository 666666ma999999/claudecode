# セットアップガイド

## 依存パッケージ

```
# requirements.txt
playwright==1.57.0
python-dateutil>=2.8.2
```

## Cookie取得手順（重要）

**すべてのChromeを終了してから実行：**

```bash
# 1. Chrome終了確認
pkill -9 Chrome
pgrep Chrome  # 何も表示されなければOK

# 2. デバッグモードでChrome起動
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --remote-debugging-port=9222 --user-data-dir=/tmp/chrome-debug-profile &

# 3. 接続確認（JSON応答があればOK）
curl -s http://localhost:9222/json/version

# 4. 開いたChromeで https://twitter.com にログイン

# 5. PythonでCookie取得
python -c "
from playwright.sync_api import sync_playwright
from pathlib import Path
import json

profile_path = Path('x_profile')
profile_path.mkdir(parents=True, exist_ok=True)

with sync_playwright() as p:
    browser = p.chromium.connect_over_cdp('http://localhost:9222')
    context = browser.contexts[0]
    cookies = context.cookies()
    x_cookies = [c for c in cookies if 'twitter.com' in c.get('domain', '') or 'x.com' in c.get('domain', '')]

    cookie_file = profile_path / 'cookies.json'
    with open(cookie_file, 'w') as f:
        json.dump(x_cookies, f, indent=2)

    auth = next((c for c in x_cookies if c['name'] == 'auth_token'), None)
    print(f'Cookie保存: {len(x_cookies)}個, 認証トークン: {\"あり\" if auth else \"なし\"}')
    browser.close()
"
```

## 実行例

```bash
# 環境準備
cd /path/to/project
source venv/bin/activate

# 収集実行
python scripts/collect_tweets.py --groups group1 --scrolls 5

# 全グループ収集
python scripts/collect_tweets.py --scrolls 10
```

---

## Chrome Cookie直接抽出（CDP不要）

Chrome 145以降、CDP接続に`--user-data-dir`が必須となり、デフォルトプロファイルからのCookie取得が困難になった。代替として、ChromeのSQLiteデータベースから直接Cookie を復号・抽出する方法がある。

### 使い方

```bash
# Chromeを閉じた状態で実行（Keychain許可ダイアログが表示される）
python3 -c "
import sqlite3, json, subprocess, hashlib, tempfile, shutil, ctypes, ctypes.util, re
from pathlib import Path

key = subprocess.run(['security','find-generic-password','-w','-s','Chrome Safe Storage'], capture_output=True, text=True).stdout.strip()
dk = hashlib.pbkdf2_hmac('sha1', key.encode(), b'saltysalt', 1003, dklen=16)
lib = ctypes.cdll.LoadLibrary(ctypes.util.find_library('System'))

def decrypt(ev, k):
    if ev[:3] != b'v10': return ''
    out = ctypes.create_string_buffer(len(ev)+16)
    ol = ctypes.c_size_t(0)
    if lib.CCCrypt(1,0,1,k,len(k),b' '*16,ev[3:],len(ev)-3,out,len(out),ctypes.byref(ol)) != 0: return ''
    v = out.raw[:ol.value].decode('utf-8', errors='replace')
    m = re.findall(r'[\x20-\x7e]{4,}', v)
    return max(m, key=len) if m else v

tmp = tempfile.mktemp(suffix='.db')
shutil.copy2(Path.home()/'Library/Application Support/Google/Chrome/Default/Cookies', tmp)
conn = sqlite3.connect(tmp)
rows = conn.execute('SELECT host_key,name,encrypted_value,path,expires_utc,is_secure,is_httponly,samesite FROM cookies WHERE host_key IN (?,?,?,?)', ['.x.com','x.com','.twitter.com','twitter.com']).fetchall()
conn.close(); Path(tmp).unlink()

cookies = []
for h,n,ev,p,ex,s,ho,sa in rows:
    v = decrypt(ev, dk)
    if not v: continue
    c = {'name':n,'value':v,'domain':h,'path':p,'secure':bool(s),'httpOnly':bool(ho),'sameSite':['None','Lax','Strict'][sa] if sa in (0,1,2) else 'None'}
    if ex > 0: c['expires'] = (ex/1000000)-11644473600
    cookies.append(c)

Path('x_profile').mkdir(exist_ok=True)
with open('x_profile/cookies.json','w') as f: json.dump(cookies, f, indent=2, ensure_ascii=False)
auth = any(c['name']=='auth_token' for c in cookies)
print(f'Cookie: {len(cookies)}個 auth_token={\"あり\" if auth else \"なし\"}')
"
```

### 前提条件
- macOS専用（Keychain + CommonCrypto）
- Chromeを完全に閉じた状態で実行
- 初回はKeychain許可ダイアログで「許可」クリック

### 詳細ドキュメント
→ `~/.claude/skills/playwright-browser-automation/references/cdp-patterns.md` の「Chrome Cookie直接抽出」セクション参照
