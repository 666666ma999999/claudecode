# Coding Standards Skill

name: coding-standards
description: |
  プログラミング言語・フレームワーク別の命名規則と実装標準。新規コード生成時・既存コードレビュー時に自動適用。
  発動条件: 新規ファイル作成、API設計、コードレビュー、「命名規則」「コーディング規約」言及時

## 発動条件

以下の場面で自動適用:
- 新規Pythonファイル作成
- 新規JavaScriptファイル作成
- APIエンドポイント設計
- Pydanticモデル定義
- コードレビュー・リファクタリング
- 「命名規則」「コーディング規約」「naming convention」言及時

## 命名規則マトリクス

### 言語別基本ルール

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

## FE/BE境界の変換ルール

### 問題: 命名規則の不一致

```
BE (Python)           FE (JavaScript)
snake_case     ≠      camelCase
user_name             userName
is_active             isActive
```

手動変換はバグの温床。自動変換で解決する。

### 解決: CamelCaseModel パターン

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

console.log(user.userId);      // ✅ camelCase
console.log(user.displayName); // ✅ camelCase
console.log(user.isActive);    // ✅ camelCase
```

## 同義語・重複変数名の検出（重要）

### 問題: Case変換では検出できない重複

snake_case/camelCase変換は自動化できるが、**同じ値に異なる名前**がついているケースは自動検出できない。

```
❌ 危険パターン:
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
   # ❌ Bad: 同じ値を2つのキーで保存
   session['menu_id'] = value
   session['save_id'] = value

   # ✅ Good: 単一キー
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

## 新規コード作成チェックリスト

### Python

- [ ] 変数名・関数名が`snake_case`か
- [ ] クラス名が`PascalCase`か
- [ ] 定数が`UPPER_SNAKE_CASE`か
- [ ] APIレスポンスモデルが`CamelCaseModel`継承か
- [ ] プライベートメソッドが`_`プレフィックスか
- [ ] **同義語チェック**: 同じ値に異なる名前がないか

### JavaScript/TypeScript

- [ ] 変数名・関数名が`camelCase`か
- [ ] クラス名・コンポーネント名が`PascalCase`か
- [ ] 定数が`UPPER_SNAKE_CASE`か
- [ ] APIレスポンスを`camelCase`で参照しているか
- [ ] **同義語チェック**: BEと異なる名前で同じ値を扱っていないか

### API設計

- [ ] URLパスが`kebab-case`か
- [ ] レスポンスJSONが`camelCase`か
- [ ] エラーレスポンスも同じ規則か
- [ ] **FE/BE変数名統一**: リクエスト/レスポンスでFE/BEが同じ名前を使用（case変換のみ）

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
def getUserData(userId, includeProfile=False, withMetadata=False):  # ✅
#                                             ^^^^^^^^^^^ 既存に合わせてcamelCase

# ❌ Bad: 新規則を混ぜる
def getUserData(userId, includeProfile=False, with_metadata=False):  # ❌ 混在
```

### 例: 既存JavaScript関数への処理追加

```javascript
// 既存関数（snake_caseが混在している場合）
function process_data(input_text) {  // 既存: snake_case
    const result_array = [];  // 既存: snake_case
    // ... 既存処理 ...

    // 処理追加時: 既存規則に合わせる
    const filtered_items = result_array.filter(...);  // ✅ 既存に合わせる
    // ❌ Bad: const filteredItems = ...  // 混在させない
}
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
| ユーザーが「リファクタリング」を明示指示 | ✅ 可 |
| ファイル全体を書き直す場合 | ✅ 可 |
| 新規プロジェクト移行時 | ✅ 可 |
| バグ修正のついで | ❌ 不可 |
| 機能追加のついで | ❌ 不可 |
| 「気になったから」 | ❌ 不可 |

### チェックリスト（既存コード改修時）

- [ ] 改修対象ファイルの既存命名規則を確認したか
- [ ] 追加コードは既存規則に従っているか
- [ ] API境界のみ標準規則を適用しているか
- [ ] 命名規則変更は改修スコープ外として除外したか
- [ ] **同義語チェック**: 新規追加の変数がFE/BEで既存の別名と重複しないか

## タイムアウト設計パターン（多層防御）

長時間API処理では、BE・FEの両面で多層タイムアウトを設計すること。

### 3層タイムアウト構成

| 層 | 場所 | 役割 | 設定例 |
|----|------|------|--------|
| L1: API呼び出し | BE: 外部API呼び出し | 単一リクエストの上限 | 300秒 |
| L2: バッチ処理 | BE: バッチ全体 | 複数リクエストの合計上限 | 1800秒（30分） |
| L3: フロントエンド | FE: fetch呼び出し | ユーザー待機の上限 | 1200秒（20分） |

**必ずL1 < L3 < L2の関係を維持する。** FEタイムアウトがBEバッチより先に発火すると、BEは処理を続けるがFEはエラー表示になる。

### L1: 外部API呼び出しタイムアウト（BE）

```python
from google.generativeai.types import RequestOptions

# RequestOptionsとasyncio.wait_forの両方に設定する
req_opts = RequestOptions(timeout=300, retry=None)
response = await asyncio.wait_for(
    loop.run_in_executor(executor, lambda: model.generate_content(prompt, request_options=req_opts)),
    timeout=300  # RequestOptionsと同じ値
)
```

**ポイント:**
- ライブラリ側（RequestOptions）とアプリ側（wait_for）の両方に設定
- 片方だけだとハングする可能性がある
- フォールバック処理にも同じタイムアウト値を設定

### L1: リトライ時のタイムアウト延長

```python
if attempt < max_retries - 1:
    timeout += 30  # +10では再タイムアウトしやすい → +30推奨
    continue
```

### L2: バッチ最大タイムアウト（BE）

```python
# 大規模処理（例: 44コード×複数小見出し）を考慮した上限
return max(60, min(1800, round(calculated_timeout)))  # 最大30分
```

### L3: フロントエンドタイムアウト（FE）

```javascript
const controller = new AbortController();
const timeoutId = setTimeout(() => controller.abort(), 1200000); // 20分
try {
    const response = await fetch(url, {
        signal: controller.signal,
        // ...既存オプション
    });
} catch (err) {
    if (err.name === 'AbortError') {
        throw new Error('処理がタイムアウトしました（20分）。再試行してください。');
    }
    throw err;
} finally {
    clearTimeout(timeoutId);
}
```

**ポイント:**
- `AbortController`でfetchにタイムアウトを付与
- `finally`で必ず`clearTimeout`する
- `AbortError`を判別してユーザー向けメッセージを出す

### チェックリスト（長時間API処理の実装時）

- [ ] L1: 外部API呼び出しにタイムアウト設定（ライブラリ側+アプリ側の両方）
- [ ] L1: フォールバック処理にも同じタイムアウト値
- [ ] L1: リトライ時の延長幅が十分か（+30秒以上推奨）
- [ ] L2: バッチ全体の最大タイムアウトが最大データ量に対応しているか
- [ ] L3: FEのfetchにAbortControllerタイムアウトを設定
- [ ] L3: タイムアウト時のユーザー向けエラーメッセージ
- [ ] 関係: L1 < L3 < L2 を満たしているか

## 既存コードレビュー観点

### 命名規則違反の検出

```bash
# Python: camelCase変数の検出（違反）
grep -rn "[a-z][A-Z]" --include="*.py" | grep -v "class\|import\|#"

# JavaScript: snake_case変数の検出（違反）
grep -rn "[a-z]_[a-z]" --include="*.js" | grep -v "//\|*"

# APIレスポンスのsnake_case検出（違反の可能性）
grep -rn '"[a-z]*_[a-z]*":' --include="*.py"
```

### 修正優先度

| 優先度 | 対象 | 理由 |
|--------|------|------|
| 高 | APIレスポンス | FE/BE間の整合性に直結 |
| 中 | 公開関数・クラス | 利用者への影響 |
| 低 | 内部変数 | 影響範囲が限定的 |

## プロジェクト別カスタマイズ

各プロジェクトのCLAUDE.mdに以下を追記することで、プロジェクト固有ルールを設定:

```markdown
# 命名規則

## プロジェクト固有ルール
- APIレスポンス: camelCase（CamelCaseModel使用）
- DBカラム名: snake_case
- 環境変数: UPPER_SNAKE_CASE

## FE/BE境界
BE内部(snake_case) → API(camelCase) → FE(camelCase)
```

## 関連スキル

- **fe-be-integration**: FE/BE統合パターン、CamelCaseModelの詳細実装
- **process-state-management**: セッションデータの構造設計

## よくある間違いと修正

### 1. APIレスポンスでsnake_case

```python
# ❌ Bad
class UserResponse(BaseModel):
    user_id: str  # JSONも "user_id" で出力される

# ✅ Good
class UserResponse(CamelCaseModel):
    user_id: str  # JSONは "userId" で出力される
```

### 2. FEでsnake_caseを参照

```javascript
// ❌ Bad: BEの命名規則をFEに持ち込む
const userId = response.user_id;

// ✅ Good: FEの命名規則に従う
const userId = response.userId;
```

### 3. URL設計でcamelCase

```python
# ❌ Bad
@router.get("/api/getUserProfile")

# ✅ Good
@router.get("/api/user-profiles/{user_id}")
```

### 4. 定数で小文字

```python
# ❌ Bad
max_retries = 3
apiToken = "xxx"

# ✅ Good
MAX_RETRIES = 3
API_TOKEN = "xxx"
```

## 共通スニペット（コピー用）

新規プロジェクトで以下のパターンが必要な場合、referencesからコピーして使用:

| ファイル | 内容 |
|---------|------|
| `references/common-snippets.py` | CamelCaseModel, ValidationResponse, 標準レスポンス |
| `references/common-snippets.js` | apiRequest, ProgressAnimator, loadAppConfig |

### 使用手順

1. **検索**: プロジェクト内で既存実装を検索
   ```bash
   grep -r "class CamelCaseModel" backend/
   grep -r "function apiRequest" frontend/
   ```

2. **見つかった場合**: 既存実装をインポート/参照

3. **見つからない場合**: `references/common-snippets.*`からコピー

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
# ❌ Bad: ハードコード
async def register_step3():
    await state_manager.start_step(3, ...)

# ✅ Good: 定数参照
STEP_PPV_DETAIL = 3
async def register_ppv_detail():
    await state_manager.start_step(STEP_PPV_DETAIL, ...)
```

## 関連スキル

- **fe-be-integration**: FE/BE統合パターン、CamelCaseModelの詳細実装
- **process-state-management**: セッションデータの構造設計

## 汎用コード品質チェックリスト（Codexレビュー知見）

プロジェクト横断で発生しやすい落とし穴パターン。コードレビュー時に確認すること。

### Disconnected Pipe Pattern（最重要）

Optional引数（`default=None`）を持つ関数チェーンで、A→B→C の中間Bでパラメータが渡されていなくても、デフォルト値で静かに動作してしまう問題。

```python
# ❌ 危険: BがCにparamを渡し忘れても、Cはdefault=Noneで動く
def A(): B(param="value")
def B(param=None): C()          # paramをCに渡し忘れ
def C(param=None): use(param)   # Noneで動作 → バグが隠れる
```

**対策**: パラメータを追加・変更した際は、`grep -rn "関数名"` で全呼び出し元を検索し、値が正しく伝搬しているか確認する。

### JavaScript落とし穴

| パターン | 問題 | 対策 |
|---------|------|------|
| `if (value)` で数値チェック | `0` が falsy → 見逃す | `value != null` を使う |
| `escapeHtml(!str)` | `0`, `false` が空文字になる | `=== null \|\| === undefined` で明示チェック |
| Dict値をそのまま表示 | `[object Object]` になる | `JSON.stringify()` または個別フィールド参照 |
| ハードコード件数 `totalItems=19` | 項目追加時に不整合 | `document.querySelectorAll('.item').length` で動的取得 |

### セキュリティ（OWASP関連）

| パターン | リスク | 対策 |
|---------|--------|------|
| inline onclick + 文字列補間 | XSS | `data-*` 属性 + `addEventListener` |
| ユーザー入力をファイルパスに使用 | Path Traversal | バリデーション（`..` 排除、ホワイトリスト） |
| API応答に内部パス含む | 情報漏洩 | `str(e)` を返さず、ログのみに記録 |
| APIデータ由来のCSS class名 | CSS Injection | ホワイトリスト検証してから適用 |

### Python非同期

| パターン | リスク | 対策 |
|---------|--------|------|
| `asyncio.Lock()` をクラス変数に定義 | 複数イベントループで共有 → cross-loop risk | インスタンス変数に定義、または `__init__` 内で初期化 |
