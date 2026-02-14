# 区切り文字・セクション境界パターン

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
