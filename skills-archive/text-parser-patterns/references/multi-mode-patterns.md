# 複数モード・実装分散パターン

## パターン6: 複数入力モードのフォーマット統一

### 問題
自動生成モードと手動入力モードなど、複数の入力経路がある場合、**データフォーマットが不統一**になりやすい。
後続処理が特定フォーマットを前提としていると、一方のモードでのみ動作しない不具合が発生する。

### 実例：番号付き小見出し問題
```
自動生成モード: "1. 小見出しテキスト" → バッジ表示OK
手動入力モード: "小見出しテキスト"   → バッジ表示NG（正規表現がマッチしない）
```

後続処理の正規表現:
```javascript
// 「1. 」のような番号を期待している
const pattern = new RegExp(`(${order}\\.[^<]*${subtitle}[^<]*)(<br>|$)`);
```

### 解決策：入力データの正規化関数

```javascript
/**
 * 入力データを正規化して後続処理が期待するフォーマットに統一
 * @param {string} text - 入力テキスト
 * @returns {string} - 正規化されたテキスト
 */
function normalizeInput(text) {
    const lines = text.split('\n');
    const result = [];
    let inTargetSection = false;
    let itemNumber = 1;

    for (const line of lines) {
        const trimmed = line.trim();

        // セクション開始を検出
        if (trimmed === '【小見出し】') {
            inTargetSection = true;
            result.push(line);
            continue;
        }

        // 別セクション開始でターゲットセクション終了
        if (trimmed.startsWith('【') && trimmed.endsWith('】')) {
            inTargetSection = false;
            itemNumber = 1;  // リセット
        }

        // ターゲットセクション内で正規化を適用
        if (inTargetSection && trimmed && !trimmed.startsWith('【')) {
            // 既に番号付きならスキップ
            if (/^\d+[\.\、．]/.test(trimmed)) {
                result.push(line);
            } else {
                // 番号を付与
                result.push(`${itemNumber}. ${trimmed}`);
                itemNumber++;
            }
        } else {
            result.push(line);
        }
    }

    return result.join('\n');
}
```

### 適用パターン

```javascript
async function processInput(mode) {
    let inputData = getInputData();

    // モードに関係なく正規化を適用
    if (mode === 'manual') {
        inputData = normalizeInput(inputData);
    }
    // 自動生成モードは既に正規化済みと仮定

    // 後続処理（フォーマット統一済みのデータを使用）
    displayResults(inputData);
}
```

### チェックポイント

| 確認項目 | 説明 |
|----------|------|
| 後続処理の前提条件 | 正規表現やパターンマッチが何を期待しているか確認 |
| 入力経路の洗い出し | 自動/手動/API/ファイル読み込み等、すべての入力経路を特定 |
| 正規化のタイミング | 入力直後（後続処理の前）に正規化を適用 |
| 冪等性 | 既に正規化済みのデータに再適用しても問題ないか |

### デバッグ手順

1. **後続処理が動作しない場合**:
   ```javascript
   console.log('入力データプレビュー:', inputData.substring(0, 200));
   ```

2. **正規表現の期待値を確認**:
   ```javascript
   const testPattern = /^\d+\.\s/;
   console.log('番号付き?:', testPattern.test(firstLine));
   ```

3. **各モードでの出力を比較**:
   ```javascript
   console.log('自動モード出力:', autoModeOutput.split('\n')[0]);
   console.log('手動モード出力:', manualModeOutput.split('\n')[0]);
   ```

---

## パターン7: 同一機能の実装分散リスク

### 問題
同じ機能（例: 小見出し抽出）が複数箇所で**異なる実装**として存在する。
一方を修正しても、他方には反映されず、特定の処理フローでのみバグが発生する。

### 実例: Rohan小見出し抽出問題（2026-01-28）

```
registration.py: _extract_subtitles_from_text()
  → 「**小見出し:**」形式に対応済み
  → API /api/fortune/extract-subtitles で使用
  → テスト結果: 10件抽出OK

main.py: extract_subtitles_from_fortune_result()
  → 「**小見出し:**」形式に未対応
  → 原稿生成 /generate-all-manuscripts で使用
  → テスト結果: 0件抽出NG
```

**症状**: APIテストでは成功するが、実際の原稿生成では小見出しが認識されない

### 検出パターン

| 症状 | 原因の可能性 |
|------|-------------|
| APIテスト成功 + 実処理失敗 | API層と内部処理で別関数を使用 |
| モードAでは動作 + モードBでは失敗 | 各モードで異なるパース関数を使用 |
| 「N件指定したのにM件しか」 | 複数のパース関数で認識パターンが異なる |

### デバッグ手順

```bash
# 1. 同一機能の実装箇所を検索
grep -r "extract.*subtitle\|小見出し.*抽出" backend/

# 2. 各関数の認識パターンを比較
grep -A5 "小見出し一覧\|【小見出し】" backend/*.py

# 3. 呼び出し元を特定
grep -r "extract_subtitles_from\|_extract_subtitles" backend/
```

### 解決策

#### 方法1: 共通関数への集約（推奨）

```python
# utils/text_analysis.py に統一関数を配置
def extract_subtitles_unified(text: str) -> dict:
    """
    全フォーマット対応の小見出し抽出（一元管理）

    対応フォーマット:
    - 【小見出し】
    - 小見出し一覧
    - **小見出し:**
    - 小見出し:
    """
    # 統一実装
    ...

# 各呼び出し元から参照
from utils.text_analysis import extract_subtitles_unified
```

#### 方法2: 認識パターンの同期（暫定対応）

```python
# 両方の関数で同じパターンリストを使用
SUBTITLE_SECTION_MARKERS = [
    '小見出し一覧',
    '【小見出し】',
    '**小見出し',
    '小見出し:',
]

def is_subtitle_section_start(line: str) -> bool:
    return any(marker in line for marker in SUBTITLE_SECTION_MARKERS)
```

### 予防策

1. **新規パース関数作成時**: 既存の類似関数を検索してから実装
2. **フォーマット追加時**: 全ての関連関数に同時適用
3. **テスト時**: API層だけでなく内部関数も直接テスト

```python
# テスト例: 内部関数を直接テスト
def test_extract_subtitles_internal():
    from main import extract_subtitles_from_fortune_result
    result = extract_subtitles_from_fortune_result(test_input)
    assert len(result) == 10, "内部関数でも10件抽出されること"
```

---

## パターン8: API層とコア関数のテスト分離

### 問題
API経由のテストでは成功するが、実際の処理フローでは別の関数が使われており、
テストがバグを検出できない。

### テスト戦略

```python
# レベル1: API層テスト（E2Eに近い）
def test_api_extract_subtitles():
    response = client.post('/api/fortune/extract-subtitles', json={...})
    assert response.json()['subtitles'] == expected

# レベル2: コア関数テスト（ユニットテスト）
def test_core_extract_subtitles():
    from main import extract_subtitles_from_fortune_result
    result = extract_subtitles_from_fortune_result(test_input)
    assert result == expected

# レベル3: 統合テスト（実際の処理フロー）
def test_full_manuscript_generation():
    # /generate-all-manuscripts を呼び出し、
    # 結果の小見出し数が期待通りか確認
    response = client.post('/generate-all-manuscripts', json={...})
    manuscript = response.json()['manuscript']
    # 生成された原稿内の小見出し数を検証
```

### チェックポイント

| テストレベル | 検出できるバグ |
|-------------|---------------|
| API層のみ | APIハンドラのバグ |
| コア関数のみ | パースロジックのバグ |
| 統合テスト | 関数間の不整合、呼び出しチェーンのバグ |

---

## パターン9: 処理モード別のセクション検出スキップ

### 問題
パーサーが`mode`パラメータを受け取るが、検出ロジックで使用していない。
バッチ処理では`==コードXX==`マーカーが存在するが、個別処理（フォールバック）ではマーカーが無い。
結果、`current_code`がNullのまま、後続の`if current_code:`条件で全小見出し検出がスキップされる。

### 実例: Rohan manuscript_parser.py (2026-02-08)
```
バッチモード:  "==コード04==\n[小見出し1]..." → current_code="04" → 検出OK
個別モード:    "はい、承知いたしました。【コード04】..." → current_code=None → 全スキップ
```

### 解決策: モード別の事前設定 + 検出スキップ
```python
skip_code_detection = False
if mode == "individual" and len(expected_codes) == 1:
    raw_code = str(expected_codes[0])
    # サフィックス(N,R等)を分離して数値部分のみゼロ埋め
    suffix = ""
    numeric_part = raw_code
    if raw_code and raw_code[-1].isalpha():
        suffix = raw_code[-1]
        numeric_part = raw_code[:-1]
    current_code = f"{int(numeric_part):02d}{suffix}"
    skip_code_detection = True

# ループ内
if not skip_code_detection:
    detected_code = _detect_code_section(line_stripped)
else:
    detected_code = None
```

### 注意点
- `zfill(2)`はサフィックス付きコード(`"1N"`)で誤動作する（`"1N"`は既に長さ2なのでパディングされない）
- サフィックスを分離してから数値部分のみゼロ埋めすること
- 個別処理でもコード検出を完全に無効化するため、false positiveのリスクを理解しておく
