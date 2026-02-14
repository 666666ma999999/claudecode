---
name: data-deduplication
description: |
  FE/BEのコードベースにおけるデータ二重保持（同じデータが複数箇所に保存され、staleになるバグ）を検出・修正するパターン集。
  リファクタリング、コードレビュー、バグ調査時に使用。
  キーワード: データ二重保持, staleデータ, 古い値, 変数とDOM不一致, enum統一
metadata:
  author: masaaki-nagasawa
  version: 1.0.0
---

# データ二重保持検出・解消スキル

## 発動条件

以下のキーワード・状況で自動発動:
- 「データ二重保持」「staleデータ」「古い値が使われる」
- 「変数とDOMが合っていない」「編集後に反映されない」
- 「snake_case/camelCase不整合」「APIレスポンスのキーが違う」
- 「enum統一」「文字列リテラルをenumに」
- 「定義が複数箇所にある」「どっちが正しい？」
- フォーム値を変数にキャッシュしている箇所を発見した場合
- 同じデータが変数+DOM+APIレスポンスに三重保持されている場合

## 検出チェックリスト

リファクタリング・レビュー時に以下を順番にチェック:

### 1. FE: 変数 vs DOM 乖離

```
検索パターン:
- let xxxResult = ...  → 後でDOMを編集してもstale
- window.xxxMeta = { field: value }  → textarea編集後にstale
- xxxData.field を複数関数で参照  → フォーム変更後にstale

修正パターン: getter関数化
```

```javascript
// BAD: 変数にスナップショット保存
window.meta = { text: textareaValue };
// → ユーザーがtextarea編集後もmeta.textは古い値

// GOOD: getterで常にDOMから取得
window.meta = {
    get text() { return document.getElementById('textarea').value.trim(); }
};
```

### 2. FE: 配列+文字列+DOM 三重保持

```
検索パターン:
- let results = [];  と  let resultText = '';  が同じデータ
- results.map(r => r.content).join() === resultText

修正パターン: 配列のみ保持、文字列はgetter導出
```

```javascript
// BAD
let results = [...];
let resultText = results.map(r => r.content).join('\n');

// GOOD
let results = [...];
function getResultText() {
    return results.map(r => r.content).join('\n');
}
```

### 3. FE: フォームデータオブジェクト vs 実フォーム

```
検索パターン:
- let formData = { field: document.getElementById('x').value }
- 後で formData.field を参照（フォーム変更後stale）

修正パターン: getFormData()関数で毎回DOM読み取り
```

```javascript
// BAD
let checkData = { ppvId: document.getElementById('ppvId').value };
// → ユーザーがフォーム変更してもcheckData.ppvIdは古い

// GOOD
function getCheckFormData() {
    return {
        ppvId: document.getElementById('ppvId')?.value?.trim() || '',
    };
}
```

### 4. BE: 文字列リテラル vs enum

```
検索パターン:
grep -r '"completed"\|"failed"\|"pending"\|"running"' backend/
→ Enum定義があるのに文字列で比較している箇所

修正パターン: 全箇所でEnum使用
```

```python
# BAD
if status == "completed":

# GOOD
from .models import StepStatus
if status == StepStatus.SUCCESS:
```

### 5. BE: 同じ定義の複数箇所定義

```
検索パターン:
- STEP_DEFINITIONS が2ファイルに存在
- 同じ定数が複数ファイルにハードコード
- resume_step計算ロジックが複数実装

修正パターン: 正規ソースを1つ決め、他はimport
```

```python
# BAD: 2箇所で定義
# file_a.py: STEPS = {1: "A", 2: "B"}
# file_b.py: STEPS = {1: "A", 2: "B"}

# GOOD: 1箇所で定義、他はimport
# constants.py: STEPS = {1: "A", 2: "B"}
# file_a.py: from constants import STEPS
# file_b.py: from constants import STEPS
```

### 6. FE/BE境界: snake_case/camelCase不整合

```
検索パターン:
- BEがCamelCaseModelを使用 → レスポンスはcamelCase
- FEがsnake_caseでアクセス → KeyError/undefined

検出方法:
1. BEのレスポンスモデルがCamelCaseModel継承か確認
2. FEの該当APIレスポンス参照箇所をgrep
3. snake_caseキーがあれば不整合

修正パターン: FE側をcamelCaseに統一
```

```javascript
// BAD: BEがCamelCaseModelなのにsnake_case参照
const count = response.expected_code_count;

// GOOD
const count = response.expectedCodeCount;
```

### 7. BE: ID/値の複数箇所保持

```
検索パターン:
- ppv_id が record['ppv_id'], record['ids']['ppv_id'], state.ppv_id に分散
- 同じ値が異なるネスト構造で保持

修正パターン: 正規化ヘルパー関数
```

```python
def get_record_ids(record: dict) -> dict:
    """フォールバック付きID取得"""
    ids = record.get('ids', {})
    return {
        'ppv_id': ids.get('ppv_id') or record.get('ppv_id'),
        'menu_id': ids.get('menu_id') or record.get('menu_id'),
    }
```

## 修正時の原則

1. **READ側を修正**: 書き込み(SET)はそのまま、読み取り(GET)をgetter化
2. **段階的移行**: 全READ箇所を一度に変えず、最重要箇所から
3. **フォールバック**: getter内で旧ソースもフォールバック参照（移行期間中）
4. **構文チェック必須**: Python `ast.parse()` / JS `node -c` で毎回確認

## 関連スキル

- `fe-be-integration`: FE/BE間の定数・ロジック統合（本スキルはデータ保持に特化）
- `coding-standards`: 命名規則（本スキルは不整合検出に特化）
- `process-state-management`: ステップ状態管理（本スキルは重複排除に特化）
