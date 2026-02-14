# Phase 8: コードクリーンアップ - 詳細リファレンス

## 3段階のクリーンアップ

```
Phase A: 定数ハードコード削除
- FE側の初期値を空オブジェクトに変更
- API読み込み必須化、エラーハンドリング追加

Phase B: 完全削除
- API版が存在する関数のローカル版を削除
- 使用箇所をAPI版に変更

Phase C: 簡略化
- フォールバック用コードの最小化
- 重複ロジックの統合
```

## 削除候補の特定

```bash
# Codex MCPで分析
Codex MCPを使って、FE/BE統合後に不要になったコードを特定してください。

# Grepで確認
grep -n "function.*Local" frontend/*.js  # ローカル版
grep -n "let [A-Z_]+ = {" frontend/*.html  # ハードコード定数
```

## 削除してはいけないコード

- フォールバック関数（API失敗時に使用）
- 後方互換性のためのラッパー
- 複数箇所で使用されるユーティリティ

## Phase 8-D: フォールバック廃止（成熟段階）

**目的**: API安定化後、FEフォールバックを完全廃止しBEを唯一のソースに

**いつ実施するか**:
- APIが十分に安定している（3ヶ月以上問題なし）
- フォールバックが実際に発動していない（ログで確認）
- BEダウン時はFEも動作不能で許容される

```javascript
// Before: フォールバック付き（開発初期）
async function loadAppConfig() {
    try {
        const response = await fetch('/api/config');
        if (response.ok) return await response.json();
    } catch (e) { /* ignore */ }
    // フォールバック: ローカル定数
    return { types: {...}, limits: {...} };
}

// After: フォールバック廃止（成熟段階）
let CONFIG_LOAD_ERROR = null;

async function loadAppConfig() {
    try {
        const response = await fetch('/api/config', { cache: 'no-store' });
        if (response.ok) return await response.json();
    } catch (e) { /* continue to error */ }

    // フォールバックなし: エラーをスロー
    CONFIG_LOAD_ERROR = new Error('設定の読み込みに失敗。サーバー起動を確認してください。');
    throw CONFIG_LOAD_ERROR;
}

// 設定が必須の箇所
function getRequiredConfig() {
    if (!APP_CONFIG) {
        alert('設定が読み込まれていません。ページをリロードしてください。');
        throw new Error('CONFIG_NOT_LOADED');
    }
    return APP_CONFIG;
}
```

## ハードコード値の設定参照化

```javascript
// Before: ハードコード
const price = parseInt(input.value) || 2000;
const maxId = 999;

// After: 設定から取得
const config = getRequiredConfig();
const price = parseInt(input.value) || config.registration.default_price;
const maxId = config.registration.site_id_range.max;
```

## 移行チェックリスト

- [ ] フォールバック発動ログを1ヶ月以上確認（発動ゼロを確認）
- [ ] `isConfigLoaded()` 関数追加
- [ ] 設定必須化（未読み込み時はエラー表示）
- [ ] ハードコード値を設定参照に置換
- [ ] UI初期化を設定読み込み後に移動
