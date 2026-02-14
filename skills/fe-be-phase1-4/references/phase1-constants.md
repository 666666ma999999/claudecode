# Phase 1: 定数統合 - 詳細

## 実装パターン

```python
# BE: config.py
SHARED_CONSTANTS = {
    "types": {...},
    "limits": {...},
    "messages": {...}
}

@router.get("/api/config")
async def get_config():
    return SHARED_CONSTANTS
```

```javascript
// FE: 起動時に読み込み
let APP_CONFIG = null;
(async function initConfig() {
    const response = await fetch('/api/config', { cache: 'no-store' });
    APP_CONFIG = await response.json();
})();
```

## 落とし穴: ブラウザキャッシュ

開発中に設定値（バージョン番号など）を変更してもFEに反映されない場合、ブラウザキャッシュが原因。

```javascript
// Bad: キャッシュされる可能性あり
fetch('/api/config')

// Good: キャッシュバイパス
fetch('/api/config', { cache: 'no-store' })

// Alternative: クエリ文字列でバイパス
fetch(`/api/config?_=${Date.now()}`)
```
