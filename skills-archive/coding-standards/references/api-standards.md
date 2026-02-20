# API設計・タイムアウト標準 詳細

## API命名規則

| 領域 | 規則 | 例 |
|------|------|-----|
| URLパス | kebab-case | `/api/user-profiles` |
| クエリパラメータ | snake_case | `?user_id=123` |
| JSONキー（リクエスト） | snake_case or camelCase | プロジェクトで統一 |
| JSONキー（レスポンス） | camelCase | `{"userId": 123}` |
| HTTPヘッダー | Pascal-Kebab-Case | `X-Api-Token` |
| SQLカラム名 | snake_case | `user_id`, `created_at` |
| SQLファイル名 | snake_case.sql | `create_users.sql` |

## API設計チェックリスト

- [ ] URLパスが`kebab-case`か
- [ ] レスポンスJSONが`camelCase`か
- [ ] エラーレスポンスも同じ規則か
- [ ] **FE/BE変数名統一**: リクエスト/レスポンスでFE/BEが同じ名前を使用（case変換のみ）

## よくある間違い: URL設計でcamelCase

```python
# Bad
@router.get("/api/getUserProfile")

# Good
@router.get("/api/user-profiles/{user_id}")
```

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
