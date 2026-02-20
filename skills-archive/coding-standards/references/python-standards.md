# Python コーディング標準 詳細

## 命名規則

| 要素 | 規則 | 例 |
|------|------|-----|
| 変数・関数 | snake_case | `user_name`, `get_user()` |
| クラス | PascalCase | `UserProfile` |
| 定数 | UPPER_SNAKE_CASE | `MAX_RETRIES` |
| ファイル名 | snake_case.py | `user_service.py` |
| プライベート | `_`プレフィックス | `_internal_method()` |

## FE/BE境界の変換: CamelCaseModel パターン

### 問題: 命名規則の不一致

```
BE (Python)           FE (JavaScript)
snake_case     ≠      camelCase
user_name             userName
is_active             isActive
```

手動変換はバグの温床。自動変換で解決する。

### 解決: CamelCaseModel

```python
from pydantic import BaseModel, ConfigDict

def to_camel(string: str) -> str:
    """snake_case を camelCase に変換"""
    components = string.split('_')
    return components[0] + ''.join(x.title() for x in components[1:])

class CamelCaseModel(BaseModel):
    """APIレスポンス用ベースモデル: 自動でcamelCase変換"""
    model_config = ConfigDict(
        alias_generator=to_camel,      # フィールド名変換
        populate_by_name=True,          # 元の名前でも受け付け
        serialize_by_alias=True,        # JSON出力時にalias使用
    )

# 使用例
class UserResponse(CamelCaseModel):
    user_id: str           # JSON出力: "userId"
    display_name: str      # JSON出力: "displayName"
    is_active: bool        # JSON出力: "isActive"
    created_at: datetime   # JSON出力: "createdAt"
```

### FE側での参照

```javascript
// APIレスポンスはcamelCaseで届く
const response = await fetch('/api/user/123');
const user = await response.json();

console.log(user.userId);      // camelCase
console.log(user.displayName); // camelCase
console.log(user.isActive);    // camelCase
```

## 新規コード作成チェックリスト

- [ ] 変数名・関数名が`snake_case`か
- [ ] クラス名が`PascalCase`か
- [ ] 定数が`UPPER_SNAKE_CASE`か
- [ ] APIレスポンスモデルが`CamelCaseModel`継承か
- [ ] プライベートメソッドが`_`プレフィックスか
- [ ] **同義語チェック**: 同じ値に異なる名前がないか

## 既存コード改修時のルール

### 基本原則: 周辺コードに合わせる

既存コードを改修する場合、**新規コードの命名規則より既存の一貫性を優先**する。

| 改修タイプ | 命名規則 | 理由 |
|-----------|---------|------|
| 既存関数に引数追加 | 既存関数の規則に従う | 一貫性維持 |
| 既存クラスにメソッド追加 | 既存クラスの規則に従う | 一貫性維持 |
| 既存ファイルに新関数追加 | ファイル内の支配的規則 | 混在を避ける |
| バグ修正 | 変更箇所の規則維持 | 最小変更原則 |
| 新規ファイル作成 | 標準規則（本スキル） | 新規は標準で |

### 例: 既存Python関数への引数追加

```python
# 既存関数（camelCaseで書かれている場合）
def getUserData(userId, includeProfile=False):  # 既存
    ...

# 引数追加時: 既存規則に合わせる
def getUserData(userId, includeProfile=False, withMetadata=False):  # OK
#                                             ^^^^^^^^^^^ 既存に合わせてcamelCase

# Bad: 新規則を混ぜる
def getUserData(userId, includeProfile=False, with_metadata=False):  # NG 混在
```

### 例外: API境界は常に新規則を適用

内部コードの規則に関わらず、**API境界（リクエスト/レスポンス）は常に標準規則**を適用する。

```python
# 内部関数: 既存規則(camelCase)のまま
def getUserData(userId):  # 既存規則維持
    ...

# APIレスポンス: 常にCamelCaseModel（標準規則）
class UserResponse(CamelCaseModel):
    user_id: str      # → JSON: "userId"
    display_name: str # → JSON: "displayName"

@router.get("/api/users/{user_id}")
async def get_user(user_id: str):
    data = getUserData(user_id)  # 内部は既存規則
    return UserResponse(...)      # API境界は標準規則
```

### リファクタリング時のみ命名統一

既存コードの命名規則を変更してよいのは以下の場合のみ：

| 条件 | 可否 |
|------|------|
| ユーザーが「リファクタリング」を明示指示 | 可 |
| ファイル全体を書き直す場合 | 可 |
| 新規プロジェクト移行時 | 可 |
| バグ修正のついで | 不可 |
| 機能追加のついで | 不可 |
| 「気になったから」 | 不可 |

## よくある間違いと修正

### APIレスポンスでsnake_case

```python
# Bad
class UserResponse(BaseModel):
    user_id: str  # JSONも "user_id" で出力される

# Good
class UserResponse(CamelCaseModel):
    user_id: str  # JSONは "userId" で出力される
```

### 定数で小文字

```python
# Bad
max_retries = 3
apiToken = "xxx"

# Good
MAX_RETRIES = 3
API_TOKEN = "xxx"
```

## 命名規則違反の検出

```bash
# Python: camelCase変数の検出（違反）
grep -rn "[a-z][A-Z]" --include="*.py" | grep -v "class\|import\|#"

# APIレスポンスのsnake_case検出（違反の可能性）
grep -rn '"[a-z]*_[a-z]*":' --include="*.py"
```

## Python非同期の注意点

| パターン | リスク | 対策 |
|---------|--------|------|
| `asyncio.Lock()` をクラス変数に定義 | 複数イベントループで共有 → cross-loop risk | インスタンス変数に定義、または `__init__` 内で初期化 |

## Disconnected Pipe Pattern（最重要）

Optional引数（`default=None`）を持つ関数チェーンで、A→B→C の中間Bでパラメータが渡されていなくても、デフォルト値で静かに動作してしまう問題。

```python
# 危険: BがCにparamを渡し忘れても、Cはdefault=Noneで動く
def A(): B(param="value")
def B(param=None): C()          # paramをCに渡し忘れ
def C(param=None): use(param)   # Noneで動作 → バグが隠れる
```

**対策**: パラメータを追加・変更した際は、`grep -rn "関数名"` で全呼び出し元を検索し、値が正しく伝搬しているか確認する。
