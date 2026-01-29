# エンコーディング検出パターン詳細

## バイトパターンによる判定

### UTF-8
- BOM: `EF BB BF`（オプション）
- マルチバイト: `110xxxxx 10xxxxxx`（2バイト）、`1110xxxx 10xxxxxx 10xxxxxx`（3バイト）

### Shift_JIS (CP932)
- 1バイト文字: `00-7F`, `A1-DF`（半角カナ）
- 2バイト文字: 第1バイト `81-9F`, `E0-FC`、第2バイト `40-7E`, `80-FC`

### EUC-JP
- 1バイト文字: `00-7F`
- 2バイト文字: 両バイトとも `A1-FE`
- 半角カナ: `8E A1-DF`

### ISO-2022-JP
- エスケープシーケンス使用
- `1B 24 42`（JIS X 0208開始）
- `1B 28 42`（ASCII復帰）

## JavaScript TextDecoder対応エンコーディング

```javascript
// ブラウザでサポートされる日本語エンコーディング
const japaneseEncodings = [
    'utf-8',
    'shift_jis',    // = 'csshiftjis', 'ms_kanji', 'x-sjis'
    'euc-jp',       // = 'cseucpkdfmtjapanese'
    'iso-2022-jp',  // = 'csiso2022jp'
];

// エンコーディング名のエイリアス
const encodingAliases = {
    'cp932': 'shift_jis',
    'ms932': 'shift_jis',
    'windows-31j': 'shift_jis',
    'x-euc-jp': 'euc-jp',
};
```

## Python chardet検出結果の正規化

```python
# chardetが返す可能性のある値と正規化マップ
ENCODING_NORMALIZE = {
    # Shift_JIS系
    'SHIFT_JIS': 'cp932',
    'SHIFT-JIS': 'cp932',
    'Windows-1252': 'cp932',  # 日本語ファイルの誤検出
    'ISO-8859-1': 'cp932',    # 日本語ファイルの誤検出

    # EUC-JP系
    'EUC-JP': 'euc-jp',
    'eucJP': 'euc-jp',

    # ISO-2022-JP系
    'ISO-2022-JP': 'iso-2022-jp',

    # UTF系
    'UTF-8-SIG': 'utf-8-sig',  # BOM付きUTF-8
    'UTF-16LE': 'utf-16-le',
    'UTF-16BE': 'utf-16-be',
}

def normalize_encoding(encoding: str) -> str:
    """エンコーディング名を正規化"""
    if not encoding:
        return 'utf-8'
    upper = encoding.upper().replace('_', '-')
    return ENCODING_NORMALIZE.get(upper, encoding.lower())
```

## エンコーディング判定の優先順位

1. **BOMチェック**
   - UTF-8 BOM: `EF BB BF`
   - UTF-16 LE BOM: `FF FE`
   - UTF-16 BE BOM: `FE FF`

2. **ISO-2022-JPチェック**（エスケープシーケンス検出）

3. **UTF-8試行**（厳密モード、fatal: true）

4. **日本語エンコーディング試行**
   - Shift_JIS (CP932)
   - EUC-JP

5. **フォールバック**（UTF-8、エラー無視）

## よくある問題と対処

### 問題1: chardetがWindows-1252と誤検出
日本語テキストがWindows-1252やISO-8859-1として検出される場合がある。

**対処**: 信頼度が低い場合（< 0.7）は日本語エンコーディングを試行

```python
detected = chardet.detect(raw_data)
if detected['confidence'] < 0.7:
    # 日本語エンコーディングを試行
    for enc in ['utf-8', 'cp932', 'euc-jp']:
        try:
            raw_data.decode(enc)
            return enc
        except UnicodeDecodeError:
            continue
```

### 問題2: 半角カナの誤検出
Shift_JISの半角カナ（A1-DF）がLatin-1と誤認される。

**対処**: 日本語ファイルが想定される場合は日本語エンコーディングを優先

### 問題3: 改行コードの混在
CR+LF（Windows）、LF（Unix）、CR（古いMac）が混在。

**対処**: 読み込み後に正規化
```python
text = text.replace('\r\n', '\n').replace('\r', '\n')
```
