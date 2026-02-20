# 命名規則一覧・同義語検出・識別子整合性

## 言語別命名規則マトリクス（完全版）

| 言語 | 変数・関数 | クラス | 定数 | ファイル名 |
|------|-----------|--------|------|-----------|
| Python | snake_case | PascalCase | UPPER_SNAKE_CASE | snake_case.py |
| JavaScript/TypeScript | camelCase | PascalCase | UPPER_SNAKE_CASE | camelCase.js / PascalCase.tsx |
| HTML | - | - | - | kebab-case.html |
| CSS | - | - | - | kebab-case.css |
| SQL | snake_case | - | - | snake_case.sql |

### HTML/CSS要素

| 要素 | 規則 | 例 |
|------|------|-----|
| HTML id | kebab-case | `id="user-profile"` |
| HTML class | kebab-case | `class="input-section"` |
| CSS class | kebab-case | `.input-section { }` |
| data属性 | kebab-case | `data-user-id="123"` |

### API設計

| 領域 | 規則 | 例 |
|------|------|-----|
| URLパス | kebab-case | `/api/user-profiles` |
| クエリパラメータ | snake_case | `?user_id=123` |
| JSONキー（リクエスト） | snake_case or camelCase | プロジェクトで統一 |
| JSONキー（レスポンス） | camelCase | `{"userId": 123}` |
| HTTPヘッダー | Pascal-Kebab-Case | `X-Api-Token` |

## 同義語・重複変数名の検出（重要）

### 問題: Case変換では検出できない重複

snake_case/camelCase変換は自動化できるが、**同じ値に異なる名前**がついているケースは自動検出できない。

```
危険パターン:
FE: menuId → APIに save_id として送信
BE: save_id で受信 → セッションに menu_id として保存
結果: 同じ値が2つの名前で存在 → 将来のバグの温床
```

### チェック方法

1. **FE/BEで同じ概念を表す変数を列挙**
   ```bash
   # FEのAPI呼び出しパラメータ
   grep -rn "body:.*JSON" frontend/ | grep -o "[a-zA-Z_]*:"

   # BEのリクエストモデルフィールド
   grep -rn "class.*Request" backend/ -A 10
   ```

2. **同義語候補を確認**
   | よくある同義語ペア | 統一推奨 |
   |-------------------|----------|
   | `save_id` / `menu_id` | `menu_id` |
   | `user_id` / `member_id` | `user_id` |
   | `item_name` / `product_title` | 意味で選択 |

3. **セッション/状態管理で重複キーがないか確認**
   ```python
   # Bad: 同じ値を2つのキーで保存
   session['menu_id'] = value
   session['save_id'] = value

   # Good: 単一キー
   session['menu_id'] = value
   ```

### 外部システム境界の例外

内部変数名は統一するが、**外部システムのパラメータ名は変更不可**：

```python
def register(menu_id: int):  # 内部: 統一名
    # 外部CMS API: 外部仕様に従う
    url = f"https://cms.example.com?save_id={menu_id}"
    # コメントで外部仕様である旨を明記
```

### 後方互換性

古いデータに旧名が残っている場合のフォールバック：

```python
# 新名を優先、旧名にフォールバック
menu_id = data.get('menu_id') or data.get('save_id')
```

## 識別子変更時のマルチファイル整合性

### 問題

STEP番号、フィールド名、ID名などの識別子を変更すると、複数ファイルに影響が波及する。

**例: STEP 3とSTEP 4を入れ替える場合**

| 変更箇所 | 内容 |
|---------|------|
| `backend/routers/xxx.py` | APIエンドポイントのstep番号 |
| `backend/routers/xxx_session.py` | STEP_DEFINITIONSの定義 |
| `backend/utils/xxx_automation.py` | ヘルパー関数のstep番号 |
| `frontend/xxx.html` | API呼び出し、UI表示、retry関数 |

**1ファイルでも漏れると不整合が発生する。**

### 解決策: 変更前にGrep検索

```bash
# 変更対象の識別子を全ファイルで検索
grep -rn "step=3" backend/
grep -rn "step=4" backend/
grep -rn "STEP 3" frontend/
grep -rn "STEP 4" frontend/

# 検索結果の全行を変更対象としてリスト化
```

### チェックリスト

識別子（STEP番号、フィールド名、定数名）を変更する際：

- [ ] `grep -rn "変更前の値"` で影響範囲を特定
- [ ] 検索結果の全ファイルを変更対象リストに追加
- [ ] 各ファイルで変更を実施
- [ ] 再度grepして変更漏れがないか確認
- [ ] サーバー再起動して動作確認

### よくある漏れパターン

| 漏れやすい箇所 | 例 |
|---------------|-----|
| retry関数 | `retryStep3()` の中身を更新し忘れ |
| ログメッセージ | `logger.info("STEP 3...")` の数字を更新し忘れ |
| コメント | `# STEP 3: xxx` のコメントを更新し忘れ |
| 定数定義 | `STEP_DEFINITIONS[3]` の定義を更新し忘れ |
| UI表示テキスト | `"STEP 3: xxx"` のラベルを更新し忘れ |

### 自動化の余地

頻繁に識別子変更がある場合は、定数化を検討：

```python
# Bad: ハードコード
async def register_step3():
    await state_manager.start_step(3, ...)

# Good: 定数参照
STEP_PPV_DETAIL = 3
async def register_ppv_detail():
    await state_manager.start_step(STEP_PPV_DETAIL, ...)
```
