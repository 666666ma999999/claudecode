# テスト戦略パターン

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
