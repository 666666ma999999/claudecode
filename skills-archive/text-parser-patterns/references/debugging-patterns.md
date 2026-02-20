# デバッグ・落とし穴パターン

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
        status = "OK" if marker_match else "NG"
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
    logger.warning(f"セクション数不一致: 期待{expected_count} vs 実際{actual_count}")
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
