# FE/BE命名規則リファレンス

## 基本原則

### 1. 単一の概念には単一の名前

```
❌ 悪い例:
FE: userId, memberId, visitorId  ← 同じユーザーを指す3つの名前
BE: user_id, member_id           ← 混乱の原因

✅ 良い例:
FE: userId                       ← 統一
BE: user_id                      ← 統一
```

### 2. FE/BE境界での変換ルール

```
BE内部        →  API JSON     →  FE内部
(snake_case)     (camelCase)     (camelCase)

user_id       →  userId       →  userId
menu_id       →  menuId       →  menuId
is_active     →  isActive     →  isActive
```

### 3. 外部システム境界は例外

```python
# 内部: 統一された名前
menu_id = request.menu_id

# 外部API呼び出し: 外部仕様に従う
external_api_params = {
    "save_id": menu_id,  # 外部CMSの仕様
    "item_code": product_id  # 外部決済システムの仕様
}
```

## チェックリスト

### 新規変数追加時

- [ ] 既存の類似変数がないか検索
- [ ] FEとBEで同じ名前（case変換のみ）になっているか
- [ ] セッション/状態管理で重複キーがないか

### コードレビュー時

- [ ] APIパラメータ名がFE/BEで一致
- [ ] 同じ値に複数の名前がついていないか
- [ ] 外部システム境界が明確にコメントされているか

## 危険な兆候

以下のパターンを見つけたら要注意：

1. **同じ値の複数保存**
   ```python
   session['menu_id'] = value
   session['save_id'] = value  # ← 危険：同じ値を2つのキーで保存
   ```

2. **曖昧な変数変換**
   ```javascript
   const saveId = response.menuId;  // ← 危険：名前が変わっている
   ```

3. **フォールバックの連鎖**
   ```python
   id = data.get('menu_id') or data.get('save_id') or data.get('item_id')
   # ← 3つ以上のフォールバックは設計見直しのサイン
   ```

## 統一作業の進め方

### Step 1: 現状把握
```bash
# FEでのAPI呼び出しパラメータを検索
grep -r "save_id\|saveId" frontend/

# BEでのフィールド名を検索
grep -r "save_id\|menu_id" backend/
```

### Step 2: 対応表作成

| 現在の名前 | 統一後の名前 | 理由 |
|-----------|-------------|------|
| save_id (BE) | menu_id | 意味が明確 |
| saveId (FE) | menuId | BEに合わせる |

### Step 3: 段階的移行

1. BEモデルを変更
2. 後方互換フォールバックを追加
3. FEを変更
4. テスト
5. 古いフォールバックを削除（将来）

## 命名規則早見表

| 概念 | BE (Python) | API JSON | FE (JavaScript) |
|------|-------------|----------|-----------------|
| ユーザーID | user_id | userId | userId |
| メニューID | menu_id | menuId | menuId |
| サイトID | site_id | siteId | siteId |
| 有効フラグ | is_active | isActive | isActive |
| 作成日時 | created_at | createdAt | createdAt |
| 更新日時 | updated_at | updatedAt | updatedAt |
