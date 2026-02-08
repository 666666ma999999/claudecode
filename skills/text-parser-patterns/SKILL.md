# テキストパーサー実装パターン

## 概要

構造化テキスト（設定ファイル、マークアップ、ユーザー入力など）をパースする際の実装パターン集。
エッジケース処理、デバッグ手法、よくある落とし穴と解決策を提供。

## 発動条件

以下のキーワード・状況で使用：
- 「パーサー」「パース」「抽出」「解析」を含むテキスト処理
- 「セクション」「区切り」「マーカー」の検出ロジック実装
- 「N個指定したのにM個しか」のようなパース結果の不一致
- 構造化テキストの読み込み・変換処理
- 「自動モードでは動くが手動モードでは動かない」等のモード間不整合
- 「番号付け」「正規化」「フォーマット統一」を含む前処理

---

## パターン1: 区切り文字とコンテンツの曖昧性解決

### 問題
`【】`、`「」`、`[]`などの文字が「セクション区切り」と「コンテンツの一部」の両方で使われる。

### 悪い例
```python
# 「」で始まる行をすべてセクション終了とみなす → 誤検出
if line.startswith('「') or line.startswith('【'):
    break  # コンテンツが「で始まる場合も終了してしまう
```

### 良い例：ホワイトリスト方式
```python
# 既知のセクションヘッダーのみで終了判定
SECTION_HEADERS = ['【占い商品】', '【ロジック】', '【設定】', '【メタデータ】']

def is_section_header(line: str) -> bool:
    stripped = line.strip()
    # 1. 既知のヘッダーに完全一致
    if stripped in SECTION_HEADERS:
        return True
    # 2. 【○○】形式で短い（セクション名らしい）
    if (stripped.startswith('【') and stripped.endswith('】') and
        len(stripped) <= 20 and '小見出し' not in stripped):
        return True
    return False
```

### 良い例：パターン除外方式
```python
# コンテンツとして許容するパターンを除外
def is_content_line(line: str) -> bool:
    stripped = line.strip()
    # 「○○」で始まるがセリフ・引用（後ろに続く文がある）
    if stripped.startswith('「') and not stripped.endswith('】'):
        return True
    # 【○○】を含むが文章の一部
    if '【' in stripped and len(stripped) > 30:
        return True
    return False
```

---

## パターン2: セクション境界の検出戦略

### 戦略A: マーカー完全一致
```python
# 最も安全だが柔軟性が低い
SUBTITLE_PATTERN = re.compile(r'^\[小見出し\d+\]$')

if SUBTITLE_PATTERN.match(line.strip()):
    # 新しいセクション開始
```

### 戦略B: 開始マーカー + 終了条件
```python
# セクション開始を検出し、次のセクションまで内容を収集
in_section = False
for line in lines:
    if line.strip() == '【小見出し】':
        in_section = True
        continue

    # 終了条件：別のセクションヘッダー or 空行が2つ続く
    if in_section and is_section_header(line):
        in_section = False
        # セクション内容を処理
```

### 戦略C: インデント/階層ベース
```python
# YAMLやPythonのようなインデントベース
def get_indent_level(line: str) -> int:
    return len(line) - len(line.lstrip())

current_level = 0
for line in lines:
    level = get_indent_level(line)
    if level < current_level:
        # 親セクションに戻った
    elif level > current_level:
        # 子セクション開始
```

---

## パターン3: パースエラーのデバッグ手順

### ステップ1: 入力データの確認
```python
# 実際の入力をそのまま保存して確認
logger.info(f"入力データ長: {len(input_text)}文字, {len(input_text.split(chr(10)))}行")
logger.debug(f"入力プレビュー: {input_text[:500]}")

# セッションやログに保存
with open(f'debug_{timestamp}.txt', 'w') as f:
    f.write(input_text)
```

### ステップ2: マーカー検出のトレース
```python
# 各行のマーカー検出結果をログ出力
for i, line in enumerate(lines):
    stripped = line.strip()
    marker_match = MARKER_PATTERN.match(stripped)
    if stripped.startswith('[') or stripped.startswith('【'):
        status = "✅" if marker_match else "❌"
        logger.debug(f"行{i}: {status} '{stripped[:50]}' (len={len(stripped)})")
```

### ステップ3: 中間データの検証
```python
# パース後の構造化データを検証
result = parse_text(input_text)
logger.info(f"パース結果: {len(result.get('sections', []))}セクション")
for section in result.get('sections', []):
    logger.info(f"  - {section.get('title', 'N/A')}: {len(section.get('content', ''))}文字")
```

### ステップ4: 期待値との比較
```python
# 入力から期待されるセクション数を別の方法でカウント
expected_count = input_text.count('[小見出し')  # 簡易カウント
actual_count = len(result.get('sections', []))
if expected_count != actual_count:
    logger.warning(f"⚠️ セクション数不一致: 期待{expected_count} vs 実際{actual_count}")
```

---

## パターン4: よくある落とし穴

### 落とし穴1: 正規表現の`$`と改行
```python
# 悪い例：$は改行の前にマッチしない場合がある
pattern = r'^\[section\]$'

# 良い例：stripしてからマッチ
if re.match(r'^\[section\]$', line.strip()):
    ...
```

### 落とし穴2: 空白文字の扱い
```python
# 悪い例：見えない文字（BOM、全角スペース）を見落とす
if line == '[section]':
    ...

# 良い例：正規化してから比較
import unicodedata
normalized = unicodedata.normalize('NFKC', line.strip())
if normalized == '[section]':
    ...
```

### 落とし穴3: ループの早期終了
```python
# 悪い例：最初のエラーで全体が失敗
for line in lines:
    if error_condition:
        break  # 残りのデータが処理されない

# 良い例：エラーを記録して継続
errors = []
for line in lines:
    try:
        process(line)
    except ParseError as e:
        errors.append((line_num, str(e)))
        continue  # 次の行を処理
```

### 落とし穴4: `\s*` が改行を含む問題（Python/JS共通）
```python
# 悪い例：\s* は改行(\n)を含むため、意図せず次行もマッチする
re.search(r'【占い商品】\s*([^\n]+)', text)
# → 【占い商品】\n次の行 にもマッチしてしまう

# 良い例：改行を除く空白のみマッチさせる [^\S\n]*
re.search(r'【占い商品】[^\S\n]*([^\n]+)', text)  # 同一行のみ
re.search(r'【占い商品】[^\S\n]*\n([^\n]+)', text)  # 次行のみ
```
```javascript
// JS版：\s は改行を含むので同様の注意が必要
// 悪い例
fortuneResult.match(/【占い商品】\s*([^\n]+)/);
// 良い例：同一行 or 次行
fortuneResult.match(/【占い商品】[^\S\n]*\n?([^\n]+)/);
```

### 落とし穴5: 状態管理のリセット忘れ
```python
# 悪い例：前のセクションの状態が残る
current_section = None
for line in lines:
    if is_section_start(line):
        # current_sectionをリセットせずに上書き
        current_section = {'title': line}

# 良い例：明示的にリセット
for line in lines:
    if is_section_start(line):
        if current_section:
            save_section(current_section)  # 前のセクションを保存
        current_section = {'title': line, 'content': []}  # 新規初期化
```

---

## パターン5: テスト戦略

### エッジケーステストデータ
```python
TEST_CASES = [
    # 正常系
    ("【セクション】\n内容", 1, "基本ケース"),

    # エッジケース：コンテンツに区切り文字
    ("【セクション】\n「引用」を含む内容", 1, "引用符開始"),
    ("【セクション】\n【強調】を含む内容", 1, "括弧含む"),

    # エッジケース：連続・空
    ("【A】\n【B】\n【C】", 3, "連続セクション"),
    ("【A】\n\n\n【B】", 2, "空行あり"),

    # 境界値
    ("", 0, "空入力"),
    ("【】", 0, "空セクション名"),
]

for input_text, expected_count, description in TEST_CASES:
    result = parse(input_text)
    assert len(result) == expected_count, f"Failed: {description}"
```

---

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

---

## 実装チェックリスト

- [ ] 区切り文字がコンテンツにも現れる可能性を考慮したか
- [ ] 既知のセクションヘッダーをホワイトリストで管理しているか
- [ ] 入力データのデバッグログを出力できるか
- [ ] マーカー検出のトレースログを追加したか
- [ ] 期待値と実際の結果を比較する検証を入れたか
- [ ] 空入力、空行、特殊文字のエッジケースをテストしたか
- [ ] ループの早期終了が意図したものか確認したか
- [ ] 状態変数のリセットを明示的に行っているか
- [ ] 複数の入力モード（自動/手動等）で出力フォーマットが統一されているか
- [ ] 後続処理が期待するフォーマットを入力データが満たしているか
- [ ] **同一機能の実装が複数箇所に分散していないか確認したか**
- [ ] **API層テストだけでなく、コア関数の直接テストも行ったか**
- [ ] **新フォーマット追加時、全ての関連パース関数に適用したか**
