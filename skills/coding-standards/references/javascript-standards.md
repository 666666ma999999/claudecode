# JavaScript/HTML/CSS コーディング標準 詳細

## JavaScript/TypeScript 命名規則

| 要素 | 規則 | 例 |
|------|------|-----|
| 変数・関数 | camelCase | `userName`, `getUserData()` |
| クラス・コンポーネント | PascalCase | `UserProfile`, `<UserCard />` |
| 定数 | UPPER_SNAKE_CASE | `MAX_RETRIES`, `API_TOKEN` |
| ファイル名（JS） | camelCase.js | `userService.js` |
| ファイル名（TSX/JSX） | PascalCase.tsx | `UserProfile.tsx` |

## HTML/CSS 命名規則

| 要素 | 規則 | 例 |
|------|------|-----|
| HTML id | kebab-case | `id="user-profile"` |
| HTML class | kebab-case | `class="input-section"` |
| CSS class | kebab-case | `.input-section { }` |
| data属性 | kebab-case | `data-user-id="123"` |
| HTMLファイル名 | kebab-case.html | `user-profile.html` |
| CSSファイル名 | kebab-case.css | `user-profile.css` |

## 新規コード作成チェックリスト

- [ ] 変数名・関数名が`camelCase`か
- [ ] クラス名・コンポーネント名が`PascalCase`か
- [ ] 定数が`UPPER_SNAKE_CASE`か
- [ ] APIレスポンスを`camelCase`で参照しているか
- [ ] **同義語チェック**: BEと異なる名前で同じ値を扱っていないか

## 既存コード改修時のルール

### 基本原則: 周辺コードに合わせる

既存コードを改修する場合、**新規コードの命名規則より既存の一貫性を優先**する。

### 例: 既存JavaScript関数への処理追加

```javascript
// 既存関数（snake_caseが混在している場合）
function process_data(input_text) {  // 既存: snake_case
    const result_array = [];  // 既存: snake_case
    // ... 既存処理 ...

    // 処理追加時: 既存規則に合わせる
    const filtered_items = result_array.filter(...);  // OK 既存に合わせる
    // Bad: const filteredItems = ...  // 混在させない
}
```

### チェックリスト（既存コード改修時）

- [ ] 改修対象ファイルの既存命名規則を確認したか
- [ ] 追加コードは既存規則に従っているか
- [ ] API境界のみ標準規則を適用しているか
- [ ] 命名規則変更は改修スコープ外として除外したか
- [ ] **同義語チェック**: 新規追加の変数がFE/BEで既存の別名と重複しないか

## よくある間違いと修正

### FEでsnake_caseを参照

```javascript
// Bad: BEの命名規則をFEに持ち込む
const userId = response.user_id;

// Good: FEの命名規則に従う
const userId = response.userId;
```

## JavaScript落とし穴パターン

| パターン | 問題 | 対策 |
|---------|------|------|
| `if (value)` で数値チェック | `0` が falsy → 見逃す | `value != null` を使う |
| `escapeHtml(!str)` | `0`, `false` が空文字になる | `=== null \|\| === undefined` で明示チェック |
| Dict値をそのまま表示 | `[object Object]` になる | `JSON.stringify()` または個別フィールド参照 |
| ハードコード件数 `totalItems=19` | 項目追加時に不整合 | `document.querySelectorAll('.item').length` で動的取得 |

## セキュリティ（OWASP関連）

| パターン | リスク | 対策 |
|---------|--------|------|
| inline onclick + 文字列補間 | XSS | `data-*` 属性 + `addEventListener` |
| ユーザー入力をファイルパスに使用 | Path Traversal | バリデーション（`..` 排除、ホワイトリスト） |
| API応答に内部パス含む | 情報漏洩 | `str(e)` を返さず、ログのみに記録 |
| APIデータ由来のCSS class名 | CSS Injection | ホワイトリスト検証してから適用 |

## 命名規則違反の検出

```bash
# JavaScript: snake_case変数の検出（違反）
grep -rn "[a-z]_[a-z]" --include="*.js" | grep -v "//\|*"
```

## 修正優先度

| 優先度 | 対象 | 理由 |
|--------|------|------|
| 高 | APIレスポンス | FE/BE間の整合性に直結 |
| 中 | 公開関数・クラス | 利用者への影響 |
| 低 | 内部変数 | 影響範囲が限定的 |
