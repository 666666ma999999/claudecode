# コードクリーンアップパターン

FE/BE統合後に発生する冗長コードを整理するためのパターン集。

## 1. クリーンアップの3フェーズ

### Phase A: 定数のハードコード削除

**対象**: FE側でハードコードされていた初期値

```javascript
// Before: ハードコード初期値
let CONSTANTS = {
    key1: 'value1',
    key2: 'value2'
};

// After: 空オブジェクト + API必須読み込み
let CONSTANTS = {};

(async function initConfig() {
    try {
        const config = await loadAppConfig();
        if (config.constants) {
            CONSTANTS = config.constants;
            console.log('✅ 設定をBEから読み込みました');
        } else {
            console.error('❌ 設定が含まれていません');
        }
    } catch (e) {
        console.error('❌ 設定読み込み失敗:', e);
    }
})();
```

**チェックリスト**:
- [ ] 初期値を空オブジェクト/配列に変更
- [ ] API読み込み成功時のログ追加
- [ ] API読み込み失敗時のエラーハンドリング追加
- [ ] 設定が空の場合の警告追加

### Phase B: 完全削除

**対象**: API版が存在し、ローカル版が不要になった関数

```javascript
// Before: ローカル関数とAPI関数が両方存在
function parseDataLocal(text) { ... }      // 30行
async function parseDataAPI(text) { ... }  // API呼び出し

// After: API関数のみ残す
async function parseDataAPI(text) { ... }

// 使用箇所の更新
// Before:
const result = parseDataLocal(text);

// After:
const apiResult = await parseDataAPI(text);
const result = apiResult.success ? apiResult.data : [];
```

**削除候補の特定方法**:
```bash
# 同じ処理名を持つ関数を検索
grep -E "function (parse|validate|format|convert).*Local" frontend/*.js
grep -E "async function (parse|validate|format|convert).*API" frontend/*.js
```

**削除前の確認**:
1. API版が同じ機能を提供しているか
2. 使用箇所が全てasync対応か
3. フォールバックが本当に不要か

### Phase C: 簡略化

**対象**: 機能は必要だがコードを簡略化できる関数

```javascript
// Before: 複雑なローカル処理
function formatTimestamp(format) {
    const pad = (n) => ('0' + n).slice(-2);
    const date = new Date();
    const y = date.getFullYear();
    // ... 20行の処理
    return formatted;
}

// After: API優先、シンプルなフォールバック
async function formatTimestamp(format) {
    try {
        const response = await fetch(`/api/timestamp?format=${format}`);
        if (response.ok) {
            const data = await response.json();
            return data.timestamp;
        }
    } catch (e) {
        console.warn('API fallback:', e);
    }
    // フォールバック: 最小限の処理
    return new Date().toISOString().replace(/[-:T.Z]/g, '').slice(0, 14);
}
```

## 2. 冗長コード特定の手順

### Step 1: Codex MCPで分析

```
Codex MCPを使って、FE/BE統合後に不要になったコードを特定してください。
以下の観点で分析:
1. BE APIが存在するローカル関数
2. ハードコードされた定数（BE設定で配信済み）
3. 重複した正規表現パターン
4. 未使用のフォールバック関数
```

### Step 2: Grepで確認

```bash
# ローカル版とAPI版の両方が存在する関数
grep -n "function.*Local\|function.*API" frontend/*.js frontend/*.html

# ハードコード定数の候補
grep -n "const [A-Z_]+ = {" frontend/*.js frontend/*.html
grep -n "let [A-Z_]+ = {" frontend/*.js frontend/*.html

# 未使用関数の候補（定義はあるが呼び出しがない）
# 関数定義を抽出
grep -oE "function [a-zA-Z_]+" frontend/*.js | sort | uniq > /tmp/defined.txt
# 関数呼び出しを抽出して比較
```

### Step 3: 使用箇所の確認

```bash
# 特定の関数の使用箇所を確認
grep -n "functionName" frontend/*.js frontend/*.html

# 使用箇所がなければ削除候補
```

## 3. 削除の安全な手順

### 3.1 バックアップ

```bash
# 変更前にコミット
git add -A && git commit -m "backup before cleanup"
```

### 3.2 段階的削除

1. **使用箇所をAPI版に変更**
2. **テスト実行**
3. **ローカル関数を削除**
4. **再テスト**

### 3.3 検証

```bash
# サーバー再起動
./stop_servers.sh && ./start_unified_server.sh

# ヘルスチェック
curl -s -o /dev/null -w "%{http_code}" http://localhost:5558/

# APIエンドポイント確認
curl -s http://localhost:5558/api/config | jq 'keys'
```

## 4. 削除してはいけないコード

### フォールバック関数
API失敗時のフォールバックは残す:
```javascript
// 残す: API失敗時に使用
function formatTimestampLocal(format) { ... }

async function getTimestamp(format) {
    try {
        return await fetchTimestampAPI(format);
    } catch (e) {
        return formatTimestampLocal(format);  // フォールバック
    }
}
```

### 同期関数のラッパー
既存の同期関数インターフェースを維持する場合:
```javascript
// 残す: 後方互換性のため
function parseData(text) {
    return parseDataLocal(text);
}
```

### ユーティリティ関数
複数箇所で使用される汎用関数:
```javascript
// 残す: 複数箇所で使用
function escapeHtml(text) { ... }
function padZero(n) { ... }
```

## 5. クリーンアップ効果の測定

### 行数削減

```bash
# Before/Afterの行数比較
wc -l frontend/*.js frontend/*.html
```

### 関数数削減

```bash
# 関数定義数
grep -c "function " frontend/*.js frontend/*.html
```

### バンドルサイズ（該当する場合）

```bash
# ビルド後のサイズ比較
ls -la dist/*.js
```

## 6. 共通ヘルパー関数の抽出

### 問題: 同じコードが複数箇所に存在

```javascript
// 場所A: executeRegistration()
const yudoPpvId01 = yudoRecommendResult?.success ? yudoRecommendResult.yudo_ppv_id_01 : null;
const yudoMenuId01 = yudoRecommendResult?.success ? yudoRecommendResult.yudo_menu_id_01 : null;
const yudoPpvId02 = yudoRecommendResult?.success ? yudoRecommendResult.yudo_ppv_id_02 : null;
const yudoMenuId02 = yudoRecommendResult?.success ? yudoRecommendResult.yudo_menu_id_02 : null;

// 場所B: retryStep3()
// 同じコード...

// 場所C: retryStep4()
// 同じコード...
```

### 解決: ヘルパー関数に統合

```javascript
/**
 * yudoパラメータを取得（重複削減用ヘルパー）
 * @returns {object} yudoパラメータ
 */
function getYudoParams() {
    // セッションから取得（優先）
    if (registrationRecord?.distribution?.yudo) {
        return registrationRecord.distribution.yudo;
    }
    // フォールバック: グローバル変数から取得
    return {
        txt: yudoTxtResult?.generated_text || null,
        ppv01: yudoRecommendResult?.yudo_ppv_id_01 || null,
        menu01: yudoRecommendResult?.yudo_menu_id_01 || null,
        ppv02: yudoRecommendResult?.yudo_ppv_id_02 || null,
        menu02: yudoRecommendResult?.yudo_menu_id_02 || null
    };
}

// 使用箇所（全て統一）
const yudo = getYudoParams();
await fetch('/api/cms-menu/register', {
    body: JSON.stringify({
        yudo_ppv_id_01: yudo.ppv01,
        yudo_menu_id_01: yudo.menu01,
        // ...
    })
});
```

### ヘルパー関数抽出の候補特定

```bash
# 同じ変数参照が複数箇所にあるか確認
grep -n "yudoRecommendResult\." frontend/*.html | wc -l

# 3箇所以上あれば抽出候補
```

### 効果

| Before | After | 削減 |
|--------|-------|------|
| 3箇所 x 8行 = 24行 | 1関数 12行 | 50% |

## 7. 実例: Rohanプロジェクトでの削除

### 削除したコード

| コード | 行数 | 理由 |
|--------|------|------|
| KOMI_GENERATE_MODES初期値 | 7行 | BE設定から読み込み |
| REGISTRATION_CONSTANTS初期値 | 5行 | BE設定から読み込み |
| parseManuscriptSections関数 | 30行 | API版に統合 |

### 残したコード

| コード | 理由 |
|--------|------|
| formatTimestampLocal | フォールバック用 |
| validateAttachedFiles | BE設定を使用済み |
| detectPersonType | シンプルで高速、API化不要 |

## 7. チェックリスト

### クリーンアップ前
- [ ] Codex MCPで冗長コード分析
- [ ] 削除候補リスト作成
- [ ] 各候補の使用箇所確認
- [ ] バックアップコミット作成

### クリーンアップ中
- [ ] Phase A: 定数ハードコード削除
- [ ] Phase B: 不要関数削除
- [ ] Phase C: 残存コード簡略化
- [ ] 各フェーズ後にテスト

### クリーンアップ後
- [ ] サーバー再起動
- [ ] ヘルスチェック（200確認）
- [ ] 主要API動作確認
- [ ] VERSION_HISTORY.md更新
- [ ] 削減効果の記録
